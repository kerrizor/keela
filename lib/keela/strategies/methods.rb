# frozen_string_literal: true

module Keela
  module Strategies
    class Methods < Strategy
      def name
        "methods"
      end

      def default_definition_file_pattern
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
          # Regular method: match calls and symbol references
          # Matches:
          #   - Direct calls: foo(arg), obj.foo
          #   - Symbol references: :foo, :foo! (callbacks, send, etc.)
          # Excludes:
          #   - Definitions: def foo, def self.foo
          #   - Partial matches: :foobar, before_foo (via word boundary lookbehind)
          /(?<!def |def self\.)(?<![A-Za-z0-9_]):?#{method_name}(?:\W|$)/
        end
      end

      def skip_comments?
        false
      end
    end
  end
end
