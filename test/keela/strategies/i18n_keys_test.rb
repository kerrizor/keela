# frozen_string_literal: true

require "test_helper"

class I18nKeysStrategyTest < Minitest::Test
  def setup
    @strategy = Keela::Strategies::I18nKeys.new
  end

  def test_name
    assert_equal "i18n_keys", @strategy.name
  end

  def test_definition_file_pattern_matches_locale_yml
    assert_match @strategy.definition_file_pattern, "config/locales/en.yml"
    assert_match @strategy.definition_file_pattern, "config/locales/de.yaml"
    assert_match @strategy.definition_file_pattern, "config/locales/models/user.en.yml"
  end

  def test_definition_file_pattern_does_not_match_other_files
    refute_match @strategy.definition_file_pattern, "app/models/user.rb"
    refute_match @strategy.definition_file_pattern, "config/database.yml"
  end

  def test_skip_comments
    assert @strategy.skip_comments?
  end
end

class I18nKeysExtractDefinitionsTest < Minitest::Test
  def setup
    @strategy = Keela::Strategies::I18nKeys.new
    @tmpdir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_extracts_simple_keys
    locale_file = File.join(@tmpdir, "en.yml")
    File.write(locale_file, <<~YAML)
      en:
        hello: "Hello"
        goodbye: "Goodbye"
    YAML

    definitions = @strategy.extract_definitions_from_file(locale_file, [])

    names = definitions.map { |d| d[:name] }
    assert_includes names, "hello"
    assert_includes names, "goodbye"
  end

  def test_extracts_nested_keys
    locale_file = File.join(@tmpdir, "en.yml")
    File.write(locale_file, <<~YAML)
      en:
        users:
          show:
            title: "User Profile"
            description: "View user details"
    YAML

    definitions = @strategy.extract_definitions_from_file(locale_file, [])

    names = definitions.map { |d| d[:name] }
    assert_includes names, "users.show.title"
    assert_includes names, "users.show.description"
  end

  def test_strips_locale_prefix
    locale_file = File.join(@tmpdir, "en.yml")
    File.write(locale_file, <<~YAML)
      en:
        hello: "Hello"
    YAML

    definitions = @strategy.extract_definitions_from_file(locale_file, [])

    # Should be "hello", not "en.hello"
    assert_equal ["hello"], definitions.map { |d| d[:name] }
  end

  def test_handles_locale_with_region
    locale_file = File.join(@tmpdir, "en-US.yml")
    File.write(locale_file, <<~YAML)
      en-US:
        hello: "Hello"
    YAML

    definitions = @strategy.extract_definitions_from_file(locale_file, [])

    # Should strip "en-US." prefix
    assert_equal ["hello"], definitions.map { |d| d[:name] }
  end

  def test_includes_file_in_definition
    locale_file = File.join(@tmpdir, "en.yml")
    File.write(locale_file, <<~YAML)
      en:
        hello: "Hello"
    YAML

    definitions = @strategy.extract_definitions_from_file(locale_file, [])

    assert_equal locale_file, definitions.first[:file]
  end

  def test_handles_empty_file
    locale_file = File.join(@tmpdir, "empty.yml")
    File.write(locale_file, "")

    definitions = @strategy.extract_definitions_from_file(locale_file, [])

    assert_empty definitions
  end

  def test_handles_invalid_yaml
    locale_file = File.join(@tmpdir, "invalid.yml")
    File.write(locale_file, "not: valid: yaml: {{")

    # Should not raise, just return empty and warn
    definitions = @strategy.extract_definitions_from_file(locale_file, [])

    assert_empty definitions
  end
end

class I18nKeysUsageRegexTest < Minitest::Test
  def setup
    @strategy = Keela::Strategies::I18nKeys.new
  end

  def test_matches_i18n_t_double_quotes
    regex = @strategy.usage_regex("users.show.title")
    assert_match regex, 'I18n.t("users.show.title")'
  end

  def test_matches_i18n_t_single_quotes
    regex = @strategy.usage_regex("users.show.title")
    assert_match regex, "I18n.t('users.show.title')"
  end

  def test_matches_t_helper_double_quotes
    regex = @strategy.usage_regex("users.show.title")
    assert_match regex, 't("users.show.title")'
  end

  def test_matches_t_helper_single_quotes
    regex = @strategy.usage_regex("users.show.title")
    assert_match regex, "t('users.show.title')"
  end

  def test_matches_with_interpolation_args
    regex = @strategy.usage_regex("users.greeting")
    assert_match regex, 't("users.greeting", name: user.name)'
  end

  def test_matches_with_whitespace
    regex = @strategy.usage_regex("hello")
    assert_match regex, 't( "hello" )'
  end

  def test_does_not_match_partial_key
    regex = @strategy.usage_regex("users")
    refute_match regex, 't("users.show.title")'
  end

  def test_does_not_match_different_key
    regex = @strategy.usage_regex("hello")
    refute_match regex, 't("goodbye")'
  end
end

class I18nKeysIntegrationTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @original_dir = Dir.pwd
    Dir.chdir(@tmpdir)

    # Create locale file
    FileUtils.mkdir_p("config/locales")
    File.write("config/locales/en.yml", <<~YAML)
      en:
        users:
          show:
            title: "User Profile"
            unused_key: "This is never used"
        common:
          save: "Save"
    YAML

    # Create Ruby file that uses some keys
    FileUtils.mkdir_p("app/controllers")
    File.write("app/controllers/users_controller.rb", <<~RUBY)
      class UsersController < ApplicationController
        def show
          @title = t("users.show.title")
          @save = I18n.t("common.save")
        end
      end
    RUBY
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@tmpdir)
  end

  def test_finds_unused_i18n_keys
    config = Keela::Configuration.new
    config.directory_patterns = %w[config/locales/**/*.yml app/**/*.rb]
    config.extensions = %w[yml rb]

    strategy = Keela::Strategies::I18nKeys.new
    scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

    scanner.run(force_report: true)

    unused_keys = scanner.unused_collection.values.flatten
    assert_includes unused_keys, "users.show.unused_key"
    refute_includes unused_keys, "users.show.title"
    refute_includes unused_keys, "common.save"
  end
end
