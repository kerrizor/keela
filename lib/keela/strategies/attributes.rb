# frozen_string_literal: true

module Keela
  module Strategies
    class Attributes < Strategy
      def name
        "attributes"
      end

      def default_definition_file_pattern
        # Match app/ and lib/ directories, but exclude spec/ and test/
        %r{(?:^|/)(?:ee/)?(?:app|lib)/}
      end

      def extract_definition(line)
        # Match attr_accessor, attr_reader, attr_writer declarations
        # But NOT other attr_* DSLs like attr_encrypted, attr_spammable, etc.
        return nil unless line =~ /^\s*attr_(accessor|reader|writer)\s+/

        # Extract the first symbol after the attr_* declaration
        return nil unless line =~ /attr_(?:accessor|reader|writer)\s+:(\w+)/

        Regexp.last_match(1)
      end

      def usage_regex(name)
        Regexp.union(*usage_regexes(name))
      end

      # The two ways an attribute can be used, as separate patterns:
      # - bare reference: obj.name, name, self.name = value
      # - instance variable: @name
      #
      # Excluded by the lookarounds:
      # - symbol notation (:name)
      # - the attr_* declaration itself
      # - partial word matches (username must not match name)
      #
      # These are kept apart rather than combined into one alternation because
      # an alternation has no single mandatory literal, so the regexp engine
      # cannot fast-forward to a candidate position and scans the whole source
      # instead. Checked separately, each pattern keeps its literal.
      #
      def usage_regexes(name)
        quoted = Regexp.quote(name)

        [
          /(?<!:)(?<!attr_accessor\s)(?<!attr_reader\s)(?<!attr_writer\s)(?<![a-z_])#{quoted}(?!\w)/,
          /@#{quoted}(?!\w)/
        ]
      end

      # Equivalent to matching #usage_regex, because the caller asks only
      # whether a match exists and not where it is.
      def used?(name, source)
        usage_regexes(name).any? { |regex| regex.match?(source.text) }
      end

      def skip_comments?
        true
      end
    end
  end
end
