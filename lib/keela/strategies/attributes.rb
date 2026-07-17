# frozen_string_literal: true

module Keela
  module Strategies
    class Attributes < Strategy
      def name
        "attributes"
      end

      def definition_file_pattern
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
        # Match usage of the attribute:
        # - Getter: obj.name, name (without receiver)
        # - Setter: obj.name = value, self.name = value
        # - Instance variable: @name (direct access)
        #
        # Exclude:
        # - Symbol notation (:name)
        # - The attr_* definition itself
        # - Partial word matches (username shouldn't match name)
        /(?:(?<!:)(?<!attr_accessor\s)(?<!attr_reader\s)(?<!attr_writer\s)(?<![a-z_])#{Regexp.quote(name)}(?!\w)|@#{Regexp.quote(name)}(?!\w))/
      end

      def skip_comments?
        true
      end
    end
  end
end
