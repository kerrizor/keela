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
    def definition_file_pattern
      raise NotImplementedError, "#{self.class} must implement #definition_file_pattern"
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
  end
end
