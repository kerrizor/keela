# frozen_string_literal: true

module Keela
  module Strategies
    class Delegations < Strategy
      def name
        "delegations"
      end

      def definition_file_pattern
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

        # Return single string for single method (scanner expects this)
        # For multiple methods, return first one only
        # The scanner will create one definition entry per extract_definition call
        # To handle multiple delegations per line, we'd need to change the scanner
        # For now, return just the first method
        methods.first
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

      def skip_comments?
        true
      end
    end
  end
end
