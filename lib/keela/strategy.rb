# frozen_string_literal: true

module Keela
  # Base class for detection strategies.
  #
  # Subclasses define how to find definitions and detect usage for
  # different types of code (methods, scopes, etc.)
  #
  class Strategy
    # Human-readable name for this strategy (e.g., "methods", "scopes")
    def name
      raise NotImplementedError, "#{self.class} must implement #name"
    end

    # Regex pattern to match files that may contain definitions
    # (e.g., /app\/models/ for scopes)
    #
    # Can be overridden via configuration:
    #   strategies:
    #     methods:
    #       definition_paths:
    #         - app/helpers
    #         - app/models
    #         - lib/
    #
    def definition_file_pattern
      configured_pattern || default_definition_file_pattern
    end

    # Default pattern when no configuration override is provided.
    # Subclasses should implement this instead of definition_file_pattern.
    def default_definition_file_pattern
      raise NotImplementedError, "#{self.class} must implement #default_definition_file_pattern"
    end

    # Extract a definition name from a line of code, or nil if no definition found
    def extract_definition(line)
      raise NotImplementedError, "#{self.class} must implement #extract_definition"
    end

    # Build a regex to detect usage of the given definition name
    def usage_regex(name)
      raise NotImplementedError, "#{self.class} must implement #usage_regex"
    end

    # Whether to skip lines that start with # (comments)
    def skip_comments?
      false
    end

    # Override this method for strategies that need custom file parsing
    # (e.g., YAML files for I18n keys).
    # Returns an array of { name:, file: } hashes, or nil to use default line-by-line parsing.
    def extract_definitions_from_file(_filepath, _lines)
      nil
    end

    private

    def configured_pattern
      paths = Keela.configuration.options_for(name)["definition_paths"]
      return nil unless paths.is_a?(Array) && paths.any?

      escaped = paths.map { |p| Regexp.escape(p.to_s) }
      Regexp.new(escaped.join("|"))
    end
  end
end
