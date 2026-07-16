# frozen_string_literal: true

require "test_helper"

class KeelaTest < Minitest::Test
  def teardown
    Keela.reset_configuration!
  end

  def test_has_version
    refute_nil Keela::VERSION
  end

  def test_version_is_semantic
    assert_match(/\A\d+\.\d+\.\d+\z/, Keela::VERSION)
  end

  def test_configuration_returns_configuration_instance
    assert_instance_of Keela::Configuration, Keela.configuration
  end

  def test_configuration_is_memoized
    config1 = Keela.configuration
    config2 = Keela.configuration

    assert_same config1, config2
  end

  def test_configure_yields_configuration
    yielded = nil

    Keela.configure do |config|
      yielded = config
    end

    assert_same Keela.configuration, yielded
  end

  def test_configure_allows_setting_options
    Keela.configure do |config|
      config.extensions = %w[rb]
      config.baseline_path = "custom_baseline.yml"
    end

    assert_equal %w[rb], Keela.configuration.extensions
    assert_equal "custom_baseline.yml", Keela.configuration.baseline_path
  end

  def test_reset_configuration_creates_new_instance
    original = Keela.configuration
    original.extensions = %w[custom]

    Keela.reset_configuration!

    refute_same original, Keela.configuration
    assert_equal %w[rb haml erb], Keela.configuration.extensions
  end
end
