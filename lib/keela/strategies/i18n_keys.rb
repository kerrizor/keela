# frozen_string_literal: true

require "yaml"

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
    class I18nKeys < Strategy
      PLURAL_SUFFIXES = %w[zero one two few many other].freeze
      VIEW_PATH_REGEX = %r{(?:ee/)?app/views/(.+)\.html\.(?:erb|haml|slim)$}.freeze
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

      # Build a set of expanded lazy lookup keys from view files
      # Called by the scanner to detect usage via lazy lookup
      def additional_used_names(source_files)
        expanded = Set.new

        source_files.each do |filepath, lines|
          prefix = view_path_to_prefix(filepath)
          next unless prefix

          content = lines.join("\n")
          lazy_keys = extract_lazy_keys(content)

          lazy_keys.each do |lazy_key|
            # .title -> users.show.title
            full_key = "#{prefix}#{lazy_key}"
            expanded << full_key
          end
        end

        expanded
      end

      private

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
