# frozen_string_literal: true

module Keela
  module Strategies
    class Scopes < Strategy
      def name
        "scopes"
      end

      def default_definition_file_pattern
        %r{app/models}
      end

      def extract_definition(line)
        return nil unless line =~ /\bscope\s+:(\w+)/

        Regexp.last_match(1)
      end

      def usage_regex(name)
        # Whitespace-anchoring the lookbehind distinguishes a `scope :name`
        # definition (preceded by indentation whitespace) from `has_scope :name`
        # usage (preceded by `_`), which must count as a real usage.
        #
        /(?<!\sscope :)(?<!def )#{Regexp.quote(name)}\W/
      end

      def skip_comments?
        true
      end
    end
  end
end
