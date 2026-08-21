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

class I18nKeysPluralizationTest < Minitest::Test
  def setup
    @strategy = Keela::Strategies::I18nKeys.new
    @tmpdir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_pluralization_keys_include_parent_key
    locale_file = File.join(@tmpdir, "en.yml")
    File.write(locale_file, <<~YAML)
      en:
        items:
          count:
            zero: "No items"
            one: "1 item"
            other: "%{count} items"
    YAML

    definitions = @strategy.extract_definitions_from_file(locale_file, [])
    names = definitions.map { |d| d[:name] }

    # Should include both the full keys AND the parent key
    assert_includes names, "items.count.zero"
    assert_includes names, "items.count.one"
    assert_includes names, "items.count.other"
    assert_includes names, "items.count"
  end

  def test_usage_regex_matches_parent_key_for_pluralization
    # When looking for "items.count.one", should also match t("items.count")
    regex = @strategy.usage_regex("items.count.one")
    assert_match regex, 't("items.count", count: 5)'
  end

  def test_non_pluralization_keys_do_not_get_parent
    locale_file = File.join(@tmpdir, "en.yml")
    File.write(locale_file, <<~YAML)
      en:
        users:
          show:
            title: "User Profile"
    YAML

    definitions = @strategy.extract_definitions_from_file(locale_file, [])
    names = definitions.map { |d| d[:name] }

    # Should NOT include parent keys for non-pluralization
    assert_includes names, "users.show.title"
    refute_includes names, "users.show"
    refute_includes names, "users"
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

class I18nKeysPluralizationIntegrationTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @original_dir = Dir.pwd
    Dir.chdir(@tmpdir)

    # Create locale file with pluralization
    FileUtils.mkdir_p("config/locales")
    File.write("config/locales/en.yml", <<~YAML)
      en:
        items:
          count:
            zero: "No items"
            one: "1 item"
            other: "%{count} items"
        unused:
          count:
            one: "1 thing"
            other: "%{count} things"
    YAML

    # Create Ruby file that uses the parent key
    FileUtils.mkdir_p("app/views/items")
    File.write("app/views/items/index.html.erb", <<~ERB)
      <p><%= t('items.count', count: @items.size) %></p>
    ERB
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@tmpdir)
  end

  def test_pluralization_siblings_detected_as_used
    config = Keela::Configuration.new
    config.directory_patterns = %w[config/locales/**/*.yml app/**/*.erb]
    config.extensions = %w[yml erb]

    strategy = Keela::Strategies::I18nKeys.new
    scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

    scanner.run(force_report: true)

    unused_keys = scanner.unused_collection.values.flatten

    # items.count.* should all be detected as used (via parent key)
    refute_includes unused_keys, "items.count.zero"
    refute_includes unused_keys, "items.count.one"
    refute_includes unused_keys, "items.count.other"
    refute_includes unused_keys, "items.count"

    # unused.count.* should still be reported as unused
    assert_includes unused_keys, "unused.count.one"
    assert_includes unused_keys, "unused.count.other"
  end
end

class I18nKeysLazyLookupTest < Minitest::Test
  def setup
    @strategy = Keela::Strategies::I18nKeys.new
  end

  def test_view_path_to_i18n_prefix
    assert_equal "users.show", @strategy.view_path_to_prefix("app/views/users/show.html.erb")
    assert_equal "users.index", @strategy.view_path_to_prefix("app/views/users/index.html.haml")
    assert_equal "admin.users.show", @strategy.view_path_to_prefix("app/views/admin/users/show.html.erb")
  end

  def test_view_path_to_i18n_prefix_for_partials
    # Partials strip the leading underscore
    assert_equal "users.form", @strategy.view_path_to_prefix("app/views/users/_form.html.erb")
    assert_equal "shared.header", @strategy.view_path_to_prefix("app/views/shared/_header.html.erb")
  end

  def test_view_path_to_i18n_prefix_strips_ee
    assert_equal "users.show", @strategy.view_path_to_prefix("ee/app/views/users/show.html.erb")
  end

  def test_view_path_to_i18n_prefix_for_layouts
    assert_equal "layouts.application", @strategy.view_path_to_prefix("app/views/layouts/application.html.erb")
  end

  def test_extract_lazy_keys_from_content
    content = <<~ERB
      <h1><%= t('.title') %></h1>
      <p><%= t('.description') %></p>
      <p><%= t("full.key") %></p>
    ERB

    lazy_keys = @strategy.extract_lazy_keys(content)
    assert_includes lazy_keys, ".title"
    assert_includes lazy_keys, ".description"
    refute_includes lazy_keys, "full.key"
  end

  def test_extract_lazy_keys_handles_single_quotes
    content = "<%= t('.title') %>"
    lazy_keys = @strategy.extract_lazy_keys(content)
    assert_includes lazy_keys, ".title"
  end
end

class I18nKeysLazyLookupIntegrationTest < Minitest::Test
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
            description: "View user details"
            unused_key: "Never used"
        admin:
          users:
            index:
              heading: "All Users"
    YAML

    # Create view files with lazy lookup
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/show.html.erb", <<~ERB)
      <h1><%= t('.title') %></h1>
      <p><%= t('.description') %></p>
    ERB

    FileUtils.mkdir_p("app/views/admin/users")
    File.write("app/views/admin/users/index.html.erb", <<~ERB)
      <h1><%= t('.heading') %></h1>
    ERB
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@tmpdir)
  end

  def test_lazy_lookup_detected_as_used
    config = Keela::Configuration.new
    config.directory_patterns = %w[config/locales/**/*.yml app/views/**/*.erb]
    config.extensions = %w[yml erb]

    strategy = Keela::Strategies::I18nKeys.new
    scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

    scanner.run(force_report: true)

    unused_keys = scanner.unused_collection.values.flatten

    # These should be detected as used via lazy lookup
    refute_includes unused_keys, "users.show.title"
    refute_includes unused_keys, "users.show.description"
    refute_includes unused_keys, "admin.users.index.heading"

    # This should still be unused
    assert_includes unused_keys, "users.show.unused_key"
  end
end
