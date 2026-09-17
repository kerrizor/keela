# frozen_string_literal: true

module Keela
  module Strategies
    class Delegations < Strategy
      def name
        "delegations"
      end

      def default_definition_file_pattern
        # Match app/models/ directories (including concerns), but exclude spec/test
        %r{(?:^|/)(?:ee/)?app/models/}
      end

      def extract_definition(line)
        # Match delegate declarations like:
        #   delegate :name, to: :user
        #   delegate :name, :email, to: :user
        #   delegate :name, to: :user, prefix: true
        #   delegate :name, to: :user, prefix: :owner
        #   delegate :name, to: :user, allow_nil: true
        return nil unless line =~ /^\s*delegate\s+/

        # Extract the target for prefix detection
        target = line[/to:\s*:[@]?(\w+)/, 1]

        # Check for prefix option
        prefix = if line =~ /prefix:\s*:(\w+)/
                   Regexp.last_match(1)
                 elsif line =~ /prefix:\s*true/
                   target
                 end

        # Extract all method symbols from the delegate call
        # Match :symbol patterns before 'to:'
        # Include ? and ! for predicate and bang methods
        delegate_part = line.split(/,\s*to:/)[0]
        methods = delegate_part.scan(/:(\w+[?!]?)/).flatten

        return nil if methods.empty?

        # Apply prefix if present
        if prefix
          methods = methods.map { |m| "#{prefix}_#{m}" }
        end

        # Return all methods (scanner handles both single string and array)
        methods.length == 1 ? methods.first : methods
      end

      def usage_regex(name)
        # Match usage of the delegated method, but not the delegate declaration
        # Uses negative lookbehind to avoid matching:
        #   - Symbol notation (:name)
        #   - Part of delegate declaration
        # Uses word boundary to avoid partial matches
        # Note: Regexp.quote handles ? and ! in method names
        /(?<!:)(?<!delegate\s)(?<![a-z_])#{Regexp.quote(name)}(?!\w)/i
      end

      def prepare(source)
        source.fold_preserves_matching?
      end

      # Equivalent to matching #usage_regex, with the case folding moved from
      # the pattern onto the source so that the pattern can drop //i. See
      # Source#folded for why //i is the expensive part.
      #
      # The two decide alike because every guard in the pattern is
      # case-symmetric: (?<!:) and (?!\w) do not involve case, and under //i
      # both (?<![a-z_]) and (?<!delegate\s) already match their uppercase
      # forms, which a folded source no longer contains. That argument needs an
      # ASCII literal and a source whose folding preserves positions, so fall
      # back to the //i pattern when either does not hold.
      #
      def used?(name, source)
        return usage_regex(name).match?(source.text) unless name.ascii_only? && source.fold_preserves_matching?

        folded_usage_regex(name).match?(source.folded)
      end

      def skip_comments?
        true
      end

      private

      def folded_usage_regex(name)
        /(?<!:)(?<!delegate\s)(?<![a-z_])#{Regexp.quote(name.downcase(:fold))}(?!\w)/
      end
    end
  end
end
