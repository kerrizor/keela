# frozen_string_literal: true

require "json"

module Keela
  module Formatters
    class Json < Base
      def format
        output = {
          strategies: strategies.map(&:name),
          unused: non_empty_results,
          summary: {
            total: total_count,
            by_strategy: by_strategy_counts
          }
        }

        JSON.pretty_generate(output)
      end
    end
  end
end
