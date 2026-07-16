# frozen_string_literal: true

module Keela
  class Configuration
    # File extensions to scan for code usage
    attr_accessor :extensions

    # Directory patterns to scan (use %<ext>s as placeholder for extension)
    attr_accessor :directory_patterns

    # Path to YAML file listing excluded items (won't be flagged as unused)
    attr_accessor :excluded_path

    # Path to YAML file tracking known unused items (baseline)
    attr_accessor :baseline_path

    # Optional directory that must exist for scanning to proceed (e.g., "ee" for GitLab)
    attr_accessor :required_directory

    # Whether to show progress during scanning
    attr_accessor :show_progress

    def initialize
      @extensions = %w[rb haml erb].freeze
      @directory_patterns = %w[
        app/**/*.%<ext>s
        lib/**/*.%<ext>s
        config/**/*.%<ext>s
      ].freeze
      @excluded_path = nil
      @baseline_path = nil
      @required_directory = nil
      @show_progress = true
    end
  end
end
