# frozen_string_literal: true

require "yaml"
require "set"

module Keela
  module Strategies
    # Detects unused I18n translation keys in locale files.
    #
    # Definitions are extracted from YAML locale files (config/locales/*.yml)
    # and flattened to dot notation (e.g., "users.show.title").
    #
    # Usage is detected by searching for:
    #   - I18n.t("key") or I18n.t('key')
    #   - t("key") or t('key')
    #   - t(:key)
    #   - .human_attribute_name(:attr)
    #
    # Pluralization keys (zero, one, two, few, many, other) are grouped:
    # if t("items.count", count: n) is called, all siblings are considered used.
    #
    # Lazy lookup is supported: t('.title') in app/views/users/show.html.erb
    # resolves to 'users.show.title'.
    #
    # Lazy lookup in mailer/controller Ruby methods is also supported, e.g.
    # t('.greeting') in UserMailer#welcome resolves to 'user_mailer.welcome.greeting',
    # and t('.notice') in UsersController#create resolves to 'users.create.notice'.
    #
    class I18nKeys < Strategy
      PLURAL_SUFFIXES = %w[zero one two few many other].freeze
      VIEW_PATH_REGEX = %r{(?:ee/)?app/views/(.+)\.(?:html|text)\.(?:erb|haml|slim)$}.freeze
      RUBY_SCOPE_PATH_REGEX = %r{(?:ee/)?app/(?:mailers|controllers)/.+\.rb$}.freeze
      CLASS_DEF_REGEX = /^\s*class\s+([A-Z][\w:]*)/.freeze
      MODULE_DEF_REGEX = /^\s*module\s+([A-Z][\w:]*)/.freeze
      METHOD_DEF_REGEX = /^\s*def\s+(?:self\.)?([a-z_][\w]*[?!=]?)/.freeze
      LAZY_LOOKUP_REGEX = /(?:I18n\.)?t\s*\(\s*['"](\.[^'"]+)['"]/
      def name
        "i18n_keys"
      end

      def default_definition_file_pattern
        # Match locale YAML files
        %r{config/locales/.*\.ya?ml$}
      end

      # Override: I18n keys need special YAML parsing, not line-by-line
      def extract_definitions_from_file(filepath, _lines)
        return [] unless File.exist?(filepath)

        content = YAML.load_file(filepath, permitted_classes: [Symbol]) || {}
        keys = flatten_keys(content).map do |key|
          # Remove the locale prefix (e.g., "en.users.show" -> "users.show")
          key.sub(/^[a-z]{2}(-[A-Z]{2})?\./, "")
        end

        # For pluralization keys, also add the parent key so that
        # t("items.count", count: n) marks all siblings as used
        parent_keys = keys.filter_map do |key|
          parent_key_for_pluralization(key)
        end.uniq

        (keys + parent_keys).uniq.map do |key|
          { name: key, file: filepath }
        end
      rescue Psych::SyntaxError => e
        warn "Warning: Could not parse #{filepath}: #{e.message}"
        []
      end

      def extract_definition(_line)
        # Not used - we override extract_definitions_from_file instead
        nil
      end

      def usage_regex(name)
        # Match various I18n lookup patterns:
        #   I18n.t("users.show.title")
        #   I18n.t('users.show.title')
        #   t("users.show.title")
        #   t('users.show.title')
        #   t(:users_show_title) - symbol form (underscored)
        #
        # For pluralization keys, also match the parent key:
        #   t("items.count", count: n) should match items.count.one, items.count.other, etc.
        quoted_name = Regexp.quote(name)

        # Check if this is a pluralization key and build alternate pattern
        parent_key = parent_key_for_pluralization(name)
        if parent_key
          quoted_parent = Regexp.quote(parent_key)
          # Match either the exact key OR the parent key
          /(?:I18n\.)?t\s*\(\s*["':]+(?:#{quoted_name}|#{quoted_parent})["']?\s*[,)]/
        else
          # Build pattern that matches the key in quotes or as a symbol
          /(?:I18n\.)?t\s*\(\s*["':]+#{quoted_name}["']?\s*[,)]/
        end
      end

      def skip_comments?
        true
      end

      # Convert a view file path to its I18n prefix
      # "app/views/users/show.html.erb" -> "users.show"
      # "app/views/users/_form.html.erb" -> "users.form"
      # "ee/app/views/users/show.html.erb" -> "users.show"
      # "app/views/user_mailer/welcome.text.erb" -> "user_mailer.welcome"
      def view_path_to_prefix(path)
        return nil unless path =~ VIEW_PATH_REGEX

        view_path = Regexp.last_match(1)

        # Split into parts and process
        parts = view_path.split("/")

        # Handle partials: _form -> form
        parts[-1] = parts[-1].sub(/^_/, "")

        parts.join(".")
      end

      # Extract lazy lookup keys from view content
      # Returns array of keys like [".title", ".description"]
      def extract_lazy_keys(content)
        content.scan(LAZY_LOOKUP_REGEX).flatten
      end

      # Build a set of expanded lazy lookup keys from view files,
      # mailers, and controllers. Called by the scanner to detect
      # usage via lazy lookup.
      def additional_used_names(source_files)
        expanded = Set.new

        source_files.each do |filepath, lines|
          if (prefix = view_path_to_prefix(filepath))
            content = lines.join("\n")
            extract_lazy_keys(content).each do |lazy_key|
              # .title -> users.show.title
              expanded << "#{prefix}#{lazy_key}"
            end
          elsif filepath =~ RUBY_SCOPE_PATH_REGEX
            expand_ruby_lazy_keys(lines).each { |key| expanded << key }
          end
        end

        expanded
      end

      private

      # Scan a mailer/controller Ruby file line by line, tracking the current
      # class scope and method, and expand each lazy t('.x') to its full key.
      #
      # This is a pragmatic line scan (no AST) matching keela's regex style.
      # It tracks the last-seen `def` as the enclosing method and does NOT
      # attempt precise `end` matching. A lazy call that appears after a method
      # body but before the next `def` is still attributed to the last method.
      # This over-association can only mark an EXTRA key as used, never cause a
      # false "unused" flag, so it is a safe conservative tradeoff. A lazy call
      # seen before any `def` has no enclosing method and is skipped.
      #
      def expand_ruby_lazy_keys(lines)
        keys = []
        namespace = []
        class_scope = nil
        current_method = nil

        lines.each do |line|
          if (m = line.match(MODULE_DEF_REGEX))
            namespace << m[1]
          elsif (m = line.match(CLASS_DEF_REGEX))
            class_scope = ruby_class_scope(namespace, m[1])
            current_method = nil
          elsif (m = line.match(METHOD_DEF_REGEX))
            current_method = m[1]
          end

          next unless class_scope && current_method

          line.scan(LAZY_LOOKUP_REGEX).flatten.each do |lazy_key|
            # .greeting -> user_mailer.welcome.greeting
            keys << "#{class_scope}.#{current_method}#{lazy_key}"
          end
        end

        keys
      end

      # Derive the i18n scope for a class in a mailer/controller file.
      # Combines any enclosing `module` nesting with the class name (which may
      # itself be compact, e.g. `Admin::UserMailer`), underscores the full path,
      # converts "/" to ".", and drops a trailing "_controller" for controllers
      # while keeping "_mailer" for mailers.
      #
      #   [], "PaymentOrderMailer"        -> "payment_order_mailer"
      #   ["Admin"], "UserMailer"         -> "admin.user_mailer"
      #   [], "Admin::UserMailer"         -> "admin.user_mailer"
      #   [], "UsersController"           -> "users"
      #   ["Admin"], "UsersController"    -> "admin.users"
      #
      def ruby_class_scope(namespace, class_name)
        full_path = (namespace + class_name.split("::")).map { |part| underscore(part) }.join("/")
        full_path = full_path.delete_suffix("_controller") if full_path.end_with?("_controller")
        full_path.tr("/", ".")
      end

      # Convert a CamelCase constant segment to snake_case.
      # "PaymentOrderMailer" -> "payment_order_mailer"
      def underscore(word)
        word.gsub(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
            .gsub(/([a-z\d])([A-Z])/, '\1_\2')
            .downcase
      end

      # Returns the parent key if this is a pluralization key, nil otherwise
      # "items.count.one" -> "items.count"
      # "users.show.title" -> nil
      def parent_key_for_pluralization(key)
        PLURAL_SUFFIXES.each do |suffix|
          if key.end_with?(".#{suffix}")
            return key.sub(/\.#{suffix}$/, "")
          end
        end
        nil
      end

      # Flatten nested hash to dot-notation keys
      # { "en" => { "users" => { "title" => "..." } } }
      # becomes ["en.users.title"]
      def flatten_keys(hash, prefix = nil)
        hash.flat_map do |key, value|
          full_key = [prefix, key].compact.join(".")
          case value
          when Hash
            flatten_keys(value, full_key)
          else
            [full_key]
          end
        end
      end
    end
  end
end
