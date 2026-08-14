# frozen_string_literal: true

module Keela
  module Strategies
    class Methods < Strategy
      def name
        "methods"
      end

      def definition_file_pattern
        %r{app/helpers|app/models}
      end

      def extract_definition(line)
        return nil unless line =~ /def ([^(;\s]+)/

        Regexp.last_match(1).chomp
      end

      def usage_regex(name)
        method_name = Regexp.quote(name.sub(/^self\./, ""))

        if name.end_with?("=")
          # Setter method: match assignment usage
          /(?<!def |def self\.)#{method_name.chomp("=")}\W=*/
        else
          # Regular method: match calls
          # Exclude both "def foo" and "def self.foo" definitions
          /(?<!def |def self\.)#{method_name}\W/
        end
      end

      def skip_comments?
        false
      end
    end
  end
end
