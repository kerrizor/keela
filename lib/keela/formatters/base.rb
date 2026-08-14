# frozen_string_literal: true

module Keela
  module Formatters
    class Base
      attr_reader :results, :strategies

      def initialize(results:, strategies:)
        @results = results
        @strategies = strategies
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
    end
  end
end
