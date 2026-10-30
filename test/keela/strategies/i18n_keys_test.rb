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

class I18nKeysTextTemplateTest < Minitest::Test
  def setup
    @strategy = Keela::Strategies::I18nKeys.new
  end

  def test_view_path_to_prefix_resolves_text_templates
    assert_equal "user_mailer.welcome", @strategy.view_path_to_prefix("app/views/user_mailer/welcome.text.erb")
    assert_equal "user_mailer.welcome", @strategy.view_path_to_prefix("app/views/user_mailer/welcome.text.haml")
  end

  def test_view_path_to_prefix_still_resolves_html_templates
    assert_equal "user_mailer.welcome", @strategy.view_path_to_prefix("app/views/user_mailer/welcome.html.erb")
  end

  def test_additional_used_names_expands_lazy_keys_in_text_template
    source_files = {
      "app/views/user_mailer/welcome.text.erb" => ["<%= t('.body') %>"]
    }

    used = @strategy.additional_used_names(source_files)
    assert_includes used, "user_mailer.welcome.body"
  end
end

class I18nKeysRubyLazyLookupTest < Minitest::Test
  def setup
    @strategy = Keela::Strategies::I18nKeys.new
  end

  def test_lazy_lookup_in_mailer_rb
    source_files = {
      "app/mailers/payment_order_mailer.rb" => <<~RUBY.lines(chomp: true)
        class PaymentOrderMailer < ApplicationMailer
          def approval_failed
            mail(subject: t(".email_text"))
          end
        end
      RUBY
    }

    used = @strategy.additional_used_names(source_files)
    assert_includes used, "payment_order_mailer.approval_failed.email_text"
  end

  def test_lazy_lookup_in_controller_rb
    source_files = {
      "app/controllers/users_controller.rb" => <<~RUBY.lines(chomp: true)
        class UsersController < ApplicationController
          def create
            redirect_to users_path, notice: t(".notice")
          end
        end
      RUBY
    }

    used = @strategy.additional_used_names(source_files)
    assert_includes used, "users.create.notice"
  end

  def test_lazy_lookup_in_namespaced_mailer_nested_modules
    source_files = {
      "app/mailers/admin/user_mailer.rb" => <<~RUBY.lines(chomp: true)
        module Admin
          class UserMailer < ApplicationMailer
            def welcome
              mail(subject: t(".greeting"))
            end
          end
        end
      RUBY
    }

    used = @strategy.additional_used_names(source_files)
    assert_includes used, "admin.user_mailer.welcome.greeting"
  end

  def test_lazy_lookup_in_namespaced_mailer_compact_class
    source_files = {
      "app/mailers/admin/user_mailer.rb" => <<~RUBY.lines(chomp: true)
        class Admin::UserMailer < ApplicationMailer
          def welcome
            mail(subject: t(".greeting"))
          end
        end
      RUBY
    }

    used = @strategy.additional_used_names(source_files)
    assert_includes used, "admin.user_mailer.welcome.greeting"
  end

  def test_lazy_lookup_in_namespaced_controller_nested_modules
    source_files = {
      "app/controllers/admin/users_controller.rb" => <<~RUBY.lines(chomp: true)
        module Admin
          class UsersController < ApplicationController
            def create
              redirect_to admin_users_path, notice: t(".title")
            end
          end
        end
      RUBY
    }

    used = @strategy.additional_used_names(source_files)
    assert_includes used, "admin.users.create.title"
  end

  def test_lazy_lookup_in_namespaced_controller_compact_class
    source_files = {
      "app/controllers/admin/users_controller.rb" => <<~RUBY.lines(chomp: true)
        class Admin::UsersController < ApplicationController
          def create
            redirect_to admin_users_path, notice: t(".title")
          end
        end
      RUBY
    }

    used = @strategy.additional_used_names(source_files)
    assert_includes used, "admin.users.create.title"
  end

  def test_nested_lazy_key_resolves
    source_files = {
      "app/controllers/users_controller.rb" => <<~RUBY.lines(chomp: true)
        class UsersController < ApplicationController
          def create
            flash[:notice] = t(".a.b")
          end
        end
      RUBY
    }

    used = @strategy.additional_used_names(source_files)
    assert_includes used, "users.create.a.b"
  end

  def test_lazy_lookup_outside_method_is_ignored
    source_files = {
      "app/controllers/users_controller.rb" => <<~RUBY.lines(chomp: true)
        class UsersController < ApplicationController
          FOO = t(".before_any_def")
          def create
            t(".notice")
          end
        end
      RUBY
    }

    # The lazy call before any def cannot resolve to a method scope, so it is
    # skipped. The in-method call still resolves.
    used = @strategy.additional_used_names(source_files)
    refute_includes used, "users.before_any_def"
    refute(used.any? { |k| k.include?("before_any_def") })
    assert_includes used, "users.create.notice"
  end

  def test_ee_variant_mailer_resolves
    source_files = {
      "ee/app/mailers/payment_order_mailer.rb" => <<~RUBY.lines(chomp: true)
        class PaymentOrderMailer < ApplicationMailer
          def approval_failed
            mail(subject: t(".email_text"))
          end
        end
      RUBY
    }

    used = @strategy.additional_used_names(source_files)
    assert_includes used, "payment_order_mailer.approval_failed.email_text"
  end

  def test_non_lazy_explicit_key_is_not_expanded
    source_files = {
      "app/controllers/users_controller.rb" => <<~RUBY.lines(chomp: true)
        class UsersController < ApplicationController
          def create
            t("explicit.key")
          end
        end
      RUBY
    }

    # Explicit (non-lazy) keys are handled by usage_regex elsewhere, not by
    # lazy expansion. additional_used_names must not invent anything for them.
    used = @strategy.additional_used_names(source_files)
    refute(used.any? { |k| k.include?("explicit") })
  end
end

class I18nKeysRubyLazyLookupIntegrationTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @original_dir = Dir.pwd
    Dir.chdir(@tmpdir)

    FileUtils.mkdir_p("config/locales")
    File.write("config/locales/en.yml", <<~YAML)
      en:
        payment_order_mailer:
          approval_failed:
            email_text: "Approval failed"
            unused_in_mailer: "Never used"
        users:
          create:
            notice: "Created"
        user_mailer:
          welcome:
            body: "Welcome"
    YAML

    FileUtils.mkdir_p("app/mailers")
    File.write("app/mailers/payment_order_mailer.rb", <<~RUBY)
      class PaymentOrderMailer < ApplicationMailer
        def approval_failed
          mail(subject: t(".email_text"))
        end
      end
    RUBY

    FileUtils.mkdir_p("app/controllers")
    File.write("app/controllers/users_controller.rb", <<~RUBY)
      class UsersController < ApplicationController
        def create
          redirect_to users_path, notice: t(".notice")
        end
      end
    RUBY

    FileUtils.mkdir_p("app/views/user_mailer")
    File.write("app/views/user_mailer/welcome.text.erb", <<~ERB)
      <%= t('.body') %>
    ERB
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@tmpdir)
  end

  def test_lazy_lookup_in_rb_and_text_templates_detected_as_used
    config = Keela::Configuration.new
    config.directory_patterns = %w[config/locales/**/*.yml app/**/*.rb app/views/**/*.erb]
    config.extensions = %w[yml rb erb]

    strategy = Keela::Strategies::I18nKeys.new
    scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

    scanner.run(force_report: true)

    unused_keys = scanner.unused_collection.values.flatten

    refute_includes unused_keys, "payment_order_mailer.approval_failed.email_text"
    refute_includes unused_keys, "users.create.notice"
    refute_includes unused_keys, "user_mailer.welcome.body"

    assert_includes unused_keys, "payment_order_mailer.approval_failed.unused_in_mailer"
  end
end
