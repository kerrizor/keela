# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "fileutils"

class ConfigFileTest < Minitest::Test
  def setup
    @original_dir = Dir.pwd
    @temp_dir = Dir.mktmpdir
    Dir.chdir(@temp_dir)
    Keela.reset_configuration!
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@temp_dir)
    Keela.reset_configuration!
  end

  def test_loads_config_from_keela_yml
    write_config(<<~YAML)
      directory_patterns:
        - "src/**/*.%<ext>s"
        - "lib/**/*.%<ext>s"
    YAML

    Keela::ConfigFile.load

    assert_equal ["src/**/*.%<ext>s", "lib/**/*.%<ext>s"], Keela.configuration.directory_patterns
  end

  def test_loads_config_from_dot_keela_yml
    write_config(<<~YAML, filename: ".keela.yml")
      directory_patterns:
        - "custom/**/*.%<ext>s"
    YAML

    Keela::ConfigFile.load

    assert_equal ["custom/**/*.%<ext>s"], Keela.configuration.directory_patterns
  end

  def test_keela_yml_takes_precedence_over_dot_keela_yml
    write_config(<<~YAML, filename: "keela.yml")
      directory_patterns:
        - "from_keela_yml/**/*.%<ext>s"
    YAML

    write_config(<<~YAML, filename: ".keela.yml")
      directory_patterns:
        - "from_dot_keela_yml/**/*.%<ext>s"
    YAML

    Keela::ConfigFile.load

    assert_equal ["from_keela_yml/**/*.%<ext>s"], Keela.configuration.directory_patterns
  end

  def test_loads_extensions
    write_config(<<~YAML)
      extensions:
        - rb
        - rake
    YAML

    Keela::ConfigFile.load

    assert_equal %w[rb rake], Keela.configuration.extensions
  end

  def test_loads_excluded_path
    write_config(<<~YAML)
      excluded_path: "config/keela_excluded.yml"
    YAML

    Keela::ConfigFile.load

    assert_equal "config/keela_excluded.yml", Keela.configuration.excluded_path
  end

  def test_loads_baseline_path
    write_config(<<~YAML)
      baseline_path: ".keela_baseline.yml"
    YAML

    Keela::ConfigFile.load

    assert_equal ".keela_baseline.yml", Keela.configuration.baseline_path
  end

  def test_loads_required_directory
    write_config(<<~YAML)
      required_directory: "ee"
    YAML

    Keela::ConfigFile.load

    assert_equal "ee", Keela.configuration.required_directory
  end

  def test_returns_false_when_no_config_file_exists
    result = Keela::ConfigFile.load

    refute result
  end

  def test_returns_true_when_config_file_loaded
    write_config(<<~YAML)
      extensions:
        - rb
    YAML

    result = Keela::ConfigFile.load

    assert result
  end

  def test_does_not_modify_config_when_no_file_exists
    original_patterns = Keela.configuration.directory_patterns.dup

    Keela::ConfigFile.load

    assert_equal original_patterns, Keela.configuration.directory_patterns
  end

  def test_loads_from_custom_path
    custom_path = File.join(@temp_dir, "custom", "config.yml")
    FileUtils.mkdir_p(File.dirname(custom_path))
    File.write(custom_path, <<~YAML)
      extensions:
        - rb
        - jbuilder
    YAML

    Keela::ConfigFile.load(path: custom_path)

    assert_equal %w[rb jbuilder], Keela.configuration.extensions
  end

  def test_ignores_unknown_keys
    write_config(<<~YAML)
      extensions:
        - rb
      unknown_key: "should be ignored"
      another_unknown:
        - foo
        - bar
    YAML

    # Should not raise
    Keela::ConfigFile.load

    assert_equal %w[rb], Keela.configuration.extensions
  end

  def test_partial_config_only_overrides_specified_keys
    write_config(<<~YAML)
      extensions:
        - rb
        - rake
    YAML

    original_patterns = Keela.configuration.directory_patterns.dup

    Keela::ConfigFile.load

    assert_equal %w[rb rake], Keela.configuration.extensions
    assert_equal original_patterns, Keela.configuration.directory_patterns
  end

  def test_loads_exclude_patterns
    write_config(<<~YAML)
      exclude_patterns:
        - "vendor/**/*"
        - "tmp/**/*"
        - "node_modules/**/*"
    YAML

    Keela::ConfigFile.load

    assert_equal %w[vendor/**/* tmp/**/* node_modules/**/*], Keela.configuration.exclude_patterns
  end

  private

  def write_config(content, filename: "keela.yml")
    File.write(File.join(@temp_dir, filename), content)
  end
end
