# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @config = Keela::Configuration.new
  end

  def test_default_extensions
    assert_equal %w[rb haml erb], @config.extensions
  end

  def test_default_directory_patterns
    expected = %w[
      app/**/*.%<ext>s
      lib/**/*.%<ext>s
      config/**/*.%<ext>s
    ]
    assert_equal expected, @config.directory_patterns
  end

  def test_default_excluded_path_is_nil
    assert_nil @config.excluded_path
  end

  def test_default_baseline_path_is_nil
    assert_nil @config.baseline_path
  end

  def test_default_required_directory_is_nil
    assert_nil @config.required_directory
  end

  def test_default_show_progress_is_true
    assert @config.show_progress
  end

  def test_extensions_are_configurable
    @config.extensions = %w[rb]
    assert_equal %w[rb], @config.extensions
  end

  def test_directory_patterns_are_configurable
    @config.directory_patterns = %w[src/**/*.%<ext>s]
    assert_equal %w[src/**/*.%<ext>s], @config.directory_patterns
  end

  def test_excluded_path_is_configurable
    @config.excluded_path = "config/excluded.yml"
    assert_equal "config/excluded.yml", @config.excluded_path
  end

  def test_baseline_path_is_configurable
    @config.baseline_path = "config/baseline.yml"
    assert_equal "config/baseline.yml", @config.baseline_path
  end

  def test_required_directory_is_configurable
    @config.required_directory = "ee"
    assert_equal "ee", @config.required_directory
  end

  def test_show_progress_is_configurable
    @config.show_progress = false
    refute @config.show_progress
  end

  def test_default_exclude_patterns_is_empty
    assert_equal [], @config.exclude_patterns
  end

  def test_exclude_patterns_is_configurable
    @config.exclude_patterns = %w[vendor/**/* tmp/**/*]
    assert_equal %w[vendor/**/* tmp/**/*], @config.exclude_patterns
  end
end
