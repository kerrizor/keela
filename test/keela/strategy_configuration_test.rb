# frozen_string_literal: true

require "test_helper"

class StrategyConfigurationTest < Minitest::Test
  def setup
    Keela.reset_configuration!
  end

  def teardown
    Keela.reset_configuration!
  end

  def test_methods_uses_default_pattern_without_config
    strategy = Keela::Strategies::Methods.new
    assert_equal %r{app/helpers|app/models}, strategy.definition_file_pattern
  end

  def test_methods_uses_configured_definition_paths
    Keela.configuration.strategy_options = {
      "methods" => {
        "definition_paths" => ["app/helpers", "app/models", "lib/"]
      }
    }

    strategy = Keela::Strategies::Methods.new
    pattern = strategy.definition_file_pattern

    assert pattern.match?("app/helpers/foo.rb")
    assert pattern.match?("app/models/user.rb")
    assert pattern.match?("lib/utils.rb")
    refute pattern.match?("spec/models/user_spec.rb")
  end

  def test_scopes_uses_configured_definition_paths
    Keela.configuration.strategy_options = {
      "scopes" => {
        "definition_paths" => ["app/models", "ee/app/models"]
      }
    }

    strategy = Keela::Strategies::Scopes.new
    pattern = strategy.definition_file_pattern

    assert pattern.match?("app/models/user.rb")
    assert pattern.match?("ee/app/models/license.rb")
    refute pattern.match?("lib/scopes.rb")
  end

  def test_empty_definition_paths_falls_back_to_default
    Keela.configuration.strategy_options = {
      "methods" => {
        "definition_paths" => []
      }
    }

    strategy = Keela::Strategies::Methods.new
    assert_equal %r{app/helpers|app/models}, strategy.definition_file_pattern
  end

  def test_missing_strategy_config_uses_default
    Keela.configuration.strategy_options = {
      "scopes" => {
        "definition_paths" => ["custom/path"]
      }
    }

    # Methods strategy has no config, should use default
    strategy = Keela::Strategies::Methods.new
    assert_equal %r{app/helpers|app/models}, strategy.definition_file_pattern
  end

  def test_options_for_returns_empty_hash_for_unknown_strategy
    assert_equal({}, Keela.configuration.options_for("unknown"))
  end

  def test_options_for_returns_strategy_options
    Keela.configuration.strategy_options = {
      "methods" => { "definition_paths" => ["lib/"] }
    }

    assert_equal({ "definition_paths" => ["lib/"] }, Keela.configuration.options_for("methods"))
  end

  def test_definition_paths_escapes_special_regex_characters
    Keela.configuration.strategy_options = {
      "methods" => {
        "definition_paths" => ["app/models (legacy)", "lib/v2.0"]
      }
    }

    strategy = Keela::Strategies::Methods.new
    pattern = strategy.definition_file_pattern

    assert pattern.match?("app/models (legacy)/user.rb")
    assert pattern.match?("lib/v2.0/utils.rb")
    # Without escaping, "." would match any character
    refute pattern.match?("lib/v2X0/utils.rb")
  end
end
