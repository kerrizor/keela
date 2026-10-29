# frozen_string_literal: true

require "toon"

module Keela
  module Formatters
    class Toon < Base
      def format
        output = {
          "strategies" => strategies.map(&:name),
          "unused" => non_empty_results.transform_keys(&:to_s),
          "stale_exclusions" => non_empty_stale_exclusions.transform_keys(&:to_s),
          "summary" => {
            "total" => total_count,
            "by_strategy" => by_strategy_counts.transform_keys(&:to_s),
            "stale_total" => stale_total
          }
        }

        ::Toon.encode(output)
      end
    end
  end
end
