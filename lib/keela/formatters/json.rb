# frozen_string_literal: true

require "json"

module Keela
  module Formatters
    class Json < Base
      def format
        output = {
          strategies: strategies.map(&:name),
          unused: non_empty_results,
          stale_exclusions: non_empty_stale_exclusions,
          summary: {
            total: total_count,
            by_strategy: by_strategy_counts,
            stale_total: stale_total
          }
        }

        JSON.pretty_generate(output)
      end
    end
  end
end
