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
    # Note: Lazy lookup (t('.title') in views) is not yet supported.
    #
    class I18nKeys < Strategy
      def name
        "i18n_keys"
      end

      def definition_file_pattern
        # Match locale YAML files
        %r{config/locales/.*\.ya?ml$}
      end

      # Override: I18n keys need special YAML parsing, not line-by-line
      def extract_definitions_from_file(filepath, _lines)
        return [] unless File.exist?(filepath)

        content = YAML.load_file(filepath, permitted_classes: [Symbol]) || {}
        flatten_keys(content).map do |key|
          # Remove the locale prefix (e.g., "en.users.show" -> "users.show")
          key_without_locale = key.sub(/^[a-z]{2}(-[A-Z]{2})?\./, "")
          { name: key_without_locale, file: filepath }
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
        # Also match partial keys for lazy lookup support:
        #   t(".title") in a view could match "users.show.title"
        quoted_name = Regexp.quote(name)

        # Build pattern that matches the key in quotes or as a symbol
        /(?:I18n\.)?t\s*\(\s*["':]+#{quoted_name}["']?\s*[,)]/
      end

      def skip_comments?
        true
      end

      private

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
