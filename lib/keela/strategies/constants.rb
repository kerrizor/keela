# frozen_string_literal: true

module Keela
  module Strategies
    class Constants < Strategy
      def name
        "constants"
      end

      def definition_file_pattern
        # Match app/ and lib/ directories, but exclude spec/ and test/
        %r{(?:^|/)(?:ee/)?(?:app|lib)/}
      end

      def extract_definition(line)
        # Match constant definitions like:
        #   MAX_SIZE = 100
        #   ALLOWED_TYPES = %w[foo bar].freeze
        #   OPTIONS = { foo: 1 }.freeze
        #
        # Must start with uppercase letter followed by uppercase letters,
        # digits, or underscores, then = (with optional whitespace)
        #
        # Avoid matching:
        #   - Comparisons: MAX_SIZE == 100
        #   - Namespaced access: Foo::BAR
        #   - Class/module definitions

        # First check it's not a comparison
        return nil if line =~ /[!=]=/

        # Match the constant definition pattern
        return nil unless line =~ /^\s*([A-Z][A-Z0-9_]*)\s*=/

        Regexp.last_match(1)
      end

      def usage_regex(name)
        # Match usage of the constant, but not its definition
        # Uses negative lookbehind to avoid matching when preceded by
        # uppercase letters/digits/underscores (partial match)
        # Uses negative lookahead to avoid:
        #   - partial matches (followed by uppercase letters/digits/underscores)
        #   - definitions (followed by optional whitespace then =, but not ==)
        /(?<![A-Z0-9_])#{Regexp.quote(name)}(?![A-Z0-9_])(?!\s*=(?!=))/
      end

      def skip_comments?
        true
      end
    end
  end
end
