# frozen_string_literal: true

module Keela
  module Strategies
    class Scopes < Strategy
      def name
        "scopes"
      end

      def definition_file_pattern
        %r{app/models}
      end

      def extract_definition(line)
        return nil unless line =~ /\bscope\s+:(\w+)/

        Regexp.last_match(1)
      end

      def usage_regex(name)
        /(?<!scope :)(?<!def )#{Regexp.quote(name)}\W/
      end

      def skip_comments?
        true
      end
    end
  end
end
