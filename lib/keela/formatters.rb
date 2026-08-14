# frozen_string_literal: true

require_relative "formatters/base"
require_relative "formatters/json"
require_relative "formatters/toon"

module Keela
  module Formatters
    REGISTRY = {
      json: Json,
      toon: Toon
    }.freeze

    def self.for(format)
      REGISTRY[format]
    end

    def self.structured_format?(format)
      REGISTRY.key?(format)
    end
  end
end
