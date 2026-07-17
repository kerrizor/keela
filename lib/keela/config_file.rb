# frozen_string_literal: true

require "yaml"

module Keela
  # Loads configuration from a YAML file.
  #
  # Looks for config files in this order:
  #   1. keela.yml
  #   2. .keela.yml
  #
  # Supported keys:
  #   - extensions: Array of file extensions to scan
  #   - directory_patterns: Array of glob patterns for directories to scan
  #   - exclude_patterns: Array of glob patterns for files to exclude
  #   - excluded_path: Path to YAML file of excluded items
  #   - baseline_path: Path to baseline YAML file
  #   - required_directory: Directory that must exist for scanning to proceed
  #
  # Example:
  #   # keela.yml
  #   directory_patterns:
  #     - "app/**/*.%<ext>s"
  #     - "lib/**/*.%<ext>s"
  #     - "ee/app/**/*.%<ext>s"
  #     - "ee/lib/**/*.%<ext>s"
  #   extensions:
  #     - rb
  #     - haml
  #     - erb
  #
  module ConfigFile
    CONFIG_FILENAMES = %w[keela.yml .keela.yml].freeze

    ALLOWED_KEYS = %w[
      extensions
      directory_patterns
      exclude_patterns
      excluded_path
      baseline_path
      required_directory
    ].freeze

    class << self
      # Load configuration from a YAML file.
      #
      # @param path [String, nil] Optional path to config file. If nil, searches
      #   for keela.yml or .keela.yml in the current directory.
      # @return [Boolean] true if a config file was loaded, false otherwise
      #
      def load(path: nil)
        config_path = path || find_config_file
        return false unless config_path && File.exist?(config_path)

        config = YAML.load_file(config_path) || {}
        apply_config(config)
        true
      end

      private

      def find_config_file
        CONFIG_FILENAMES.find { |filename| File.exist?(filename) }
      end

      def apply_config(config)
        configuration = Keela.configuration

        ALLOWED_KEYS.each do |key|
          next unless config.key?(key)

          value = config[key]
          configuration.public_send("#{key}=", value)
        end
      end
    end
  end
end
