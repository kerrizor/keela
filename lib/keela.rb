# frozen_string_literal: true

require_relative "keela/version"
require_relative "keela/configuration"
require_relative "keela/strategy"
require_relative "keela/strategies/methods"
require_relative "keela/strategies/scopes"
require_relative "keela/strategies/constants"
require_relative "keela/strategies/delegations"
require_relative "keela/reporter"
require_relative "keela/baseline"
require_relative "keela/scanner"

module Keela
  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
