# frozen_string_literal: true

module Keela
  module Formatters
    class Base
      attr_reader :results, :strategies, :stale_exclusions

      def initialize(results:, strategies:, stale_exclusions: {})
        @results = results
        @strategies = strategies
        @stale_exclusions = stale_exclusions
      end

      def format
        raise NotImplementedError, "Subclasses must implement #format"
      end

      private

      def total_count
        results.values.flat_map(&:values).flatten.size
      end

      def by_strategy_counts
        results.transform_values { |files| files.values.flatten.size }
                .reject { |_, v| v.zero? }
      end

      def non_empty_results
        results.reject { |_, v| v.empty? }
      end

      def non_empty_stale_exclusions
        stale_exclusions.reject { |_, v| v.empty? }
      end

      def stale_total
        stale_exclusions.values.flat_map(&:values).flatten.size
      end
    end
  end
end
