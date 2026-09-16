# frozen_string_literal: true

require "test_helper"

class PartialsStrategyTest < Minitest::Test
  def setup
    @strategy = Keela::Strategies::Partials.new
  end

  def test_name
    assert_equal "partials", @strategy.name
  end

  def test_skip_comments
    assert @strategy.skip_comments?
  end

  def test_definition_file_pattern_matches_erb_partials
    assert_match @strategy.definition_file_pattern, "app/views/users/_form.html.erb"
  end

  def test_definition_file_pattern_matches_haml_partials
    assert_match @strategy.definition_file_pattern, "app/views/users/_form.html.haml"
  end

  def test_definition_file_pattern_matches_slim_partials
    assert_match @strategy.definition_file_pattern, "app/views/users/_form.html.slim"
  end

  def test_definition_file_pattern_matches_ee_partials
    assert_match @strategy.definition_file_pattern, "ee/app/views/users/_form.html.erb"
  end

  def test_definition_file_pattern_does_not_match_non_partials
    refute_match @strategy.definition_file_pattern, "app/views/users/show.html.erb"
  end

  def test_definition_file_pattern_does_not_match_spec_files
    refute_match @strategy.definition_file_pattern, "spec/views/users/_form.html.erb_spec.rb"
  end
end

class PartialsExtractDefinitionsTest < Minitest::Test
  def setup
    @strategy = Keela::Strategies::Partials.new
  end

  def test_extracts_simple_partial
    defs = @strategy.extract_definitions_from_file("app/views/_form.html.erb", [])
    assert_equal "form", defs.first[:name]
  end

  def test_extracts_nested_partial
    defs = @strategy.extract_definitions_from_file("app/views/users/_form.html.erb", [])
    assert_equal "users/form", defs.first[:name]
  end

  def test_extracts_deeply_nested_partial
    defs = @strategy.extract_definitions_from_file("app/views/admin/users/_form.html.erb", [])
    assert_equal "admin/users/form", defs.first[:name]
  end

  def test_strips_app_views_prefix
    defs = @strategy.extract_definitions_from_file("app/views/users/_form.html.erb", [])
    assert_equal "users/form", defs.first[:name]
    refute_includes defs.first[:name], "app/views"
  end

  def test_strips_ee_app_views_prefix
    defs = @strategy.extract_definitions_from_file("ee/app/views/users/_form.html.erb", [])
    assert_equal "users/form", defs.first[:name]
  end

  def test_handles_multiple_extensions
    erb = @strategy.extract_definitions_from_file("app/views/users/_form.html.erb", [])
    haml = @strategy.extract_definitions_from_file("app/views/users/_form.html.haml", [])
    slim = @strategy.extract_definitions_from_file("app/views/users/_form.html.slim", [])

    assert_equal "users/form", erb.first[:name]
    assert_equal "users/form", haml.first[:name]
    assert_equal "users/form", slim.first[:name]
  end

  def test_includes_file_in_definition
    path = "app/views/users/_form.html.erb"
    defs = @strategy.extract_definitions_from_file(path, [])
    assert_equal path, defs.first[:file]
  end
end

class PartialsUsageRegexTest < Minitest::Test
  def setup
    @strategy = Keela::Strategies::Partials.new
  end

  def test_matches_render_string_double_quotes
    regex = @strategy.usage_regex("users/form")
    assert_match regex, 'render "users/form"'
  end

  def test_matches_render_string_single_quotes
    regex = @strategy.usage_regex("users/form")
    assert_match regex, "render 'users/form'"
  end

  def test_matches_render_partial_option_double_quotes
    regex = @strategy.usage_regex("users/form")
    assert_match regex, 'render partial: "users/form"'
  end

  def test_matches_render_partial_option_single_quotes
    regex = @strategy.usage_regex("users/form")
    assert_match regex, "render partial: 'users/form'"
  end

  def test_matches_with_whitespace
    regex = @strategy.usage_regex("users/form")
    assert_match regex, 'render  partial:  "users/form"'
  end

  def test_does_not_match_partial_path
    regex = @strategy.usage_regex("users/form")
    refute_match regex, 'render "users"'
    refute_match regex, 'render "form"'
  end

  def test_does_not_match_different_partial
    regex = @strategy.usage_regex("users/form")
    refute_match regex, 'render "users/sidebar"'
  end

  # render layout: "x/y" renders the partial x/y as a layout, so it counts as
  # using that partial (single + double quotes, tolerant space).
  #
  def test_matches_render_layout_double_quotes
    regex = @strategy.usage_regex("users/form")
    assert_match regex, 'render layout: "users/form"'
  end

  def test_matches_render_layout_single_quotes
    regex = @strategy.usage_regex("users/form")
    assert_match regex, "render layout: 'users/form'"
  end
end

class PartialsIntegrationTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @original_dir = Dir.pwd
    Dir.chdir(@tmpdir)
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@tmpdir)
  end

  def scanner_for(patterns: %w[app/**/*.erb app/**/*.rb], extensions: %w[erb rb])
    config = Keela::Configuration.new
    config.directory_patterns = patterns
    config.extensions = extensions
    Keela::Scanner.new(strategy: Keela::Strategies::Partials.new, configuration: config)
  end

  def unused_names(scanner)
    scanner.run(force_report: true)
    scanner.unused_collection.values.flatten
  end

  def test_detects_unused_partial
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_unused.html.erb", "<div>never rendered</div>")

    assert_includes unused_names(scanner_for), "users/unused"
  end

  def test_does_not_flag_used_partial
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/index.html.erb", '<%= render "users/form" %>')

    refute_includes unused_names(scanner_for), "users/form"
  end

  def test_handles_ee_partials
    FileUtils.mkdir_p("ee/app/views/users")
    File.write("ee/app/views/users/_unused.html.erb", "<div>ee dead</div>")

    scanner = scanner_for(patterns: %w[ee/app/**/*.erb app/**/*.rb], extensions: %w[erb rb])
    assert_includes unused_names(scanner), "users/unused"
  end

  # DECISION 1 / DECISION 5: relative render from a sibling view marks the
  # partial used. render "form" in app/views/users/show.html.erb -> users/form.
  #
  def test_detects_relative_render_from_sibling_view
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/show.html.erb", '<%= render "form" %>')

    refute_includes unused_names(scanner_for), "users/form"
  end

  # Prior-art detail: a bareword render in a controller resolves against the
  # controller name. render "form" in users_controller.rb -> users/form.
  #
  def test_detects_relative_render_from_controller
    FileUtils.mkdir_p("app/views/users")
    FileUtils.mkdir_p("app/controllers")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/controllers/users_controller.rb", <<~RUBY)
      class UsersController < ApplicationController
        def show
          render "form"
        end
      end
    RUBY

    refute_includes unused_names(scanner_for), "users/form"
  end

  # Bareword render with explicit partial: option should also resolve relatively
  #
  def test_detects_relative_render_with_partial_option
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/show.html.erb", '<%= render partial: "form" %>')

    refute_includes unused_names(scanner_for), "users/form"
  end

  # Nested controller: admin/users_controller.rb -> admin/users/form
  #
  def test_detects_relative_render_from_nested_controller
    FileUtils.mkdir_p("app/views/admin/users")
    FileUtils.mkdir_p("app/controllers/admin")
    File.write("app/views/admin/users/_form.html.erb", "<form></form>")
    File.write("app/controllers/admin/users_controller.rb", <<~RUBY)
      class Admin::UsersController < ApplicationController
        def show
          render "form"
        end
      end
    RUBY

    refute_includes unused_names(scanner_for), "admin/users/form"
  end

  # DECISION 4: dynamic render with a variable is statically unsolvable, so the
  # partial is (correctly) reported as unused rather than guessed-at.
  #
  def test_does_not_resolve_dynamic_render
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/index.html.erb", "<%= render partial_name %>")

    assert_includes unused_names(scanner_for), "users/form"
  end

  # DECISION 3: collection/object render is documented as a limitation, not
  # implemented. render @users does NOT mark users/user used.
  #
  def test_does_not_resolve_collection_render
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_user.html.erb", "<li></li>")
    File.write("app/views/users/index.html.erb", "<%= render @users %>")

    assert_includes unused_names(scanner_for), "users/user"
  end

  # Substring matching: ensure "form" doesn't match "form_wrapper"
  #
  def test_does_not_match_substring_partials
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/_form_wrapper.html.erb", "<div></div>")
    File.write("app/views/users/index.html.erb", '<%= render "users/form" %>')

    refute_includes unused_names(scanner_for), "users/form"
    assert_includes unused_names(scanner_for), "users/form_wrapper"
  end

  # ERB comments (<%#) are NOT skipped by skip_comments? (which only skips lines
  # starting with #), so render calls in ERB comments ARE detected as usage.
  # This is a known limitation — documenting the actual behavior here.
  #
  def test_erb_comments_are_not_skipped
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/index.html.erb", "<%# render 'users/form' %>")

    # ERB comment is NOT skipped, so the partial is marked as used
    refute_includes unused_names(scanner_for), "users/form"
  end

  # render layout: "users/form" renders a partial as a layout, so the partial
  # is used (explicit path, double + single quotes).
  #
  def test_detects_render_layout_explicit_path
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/new.html.erb", '<%= render layout: "users/form" do %><% end %>')
    File.write("app/views/users/edit.html.erb", "<%= render layout: 'users/form' do %><% end %>")

    refute_includes unused_names(scanner_for), "users/form"
  end

  # Bareword render layout: "form" resolves against the calling view's dir.
  # render layout: "form" in app/views/users/show.html.erb -> users/form.
  #
  def test_detects_render_layout_bareword_from_view
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/show.html.erb", '<%= render layout: "form" do %><% end %>')

    refute_includes unused_names(scanner_for), "users/form"
  end

  # Bareword render layout: "form" in a controller resolves against the
  # controller name. render layout: "form" in users_controller.rb -> users/form.
  #
  def test_detects_render_layout_bareword_from_controller
    FileUtils.mkdir_p("app/views/users")
    FileUtils.mkdir_p("app/controllers")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/controllers/users_controller.rb", <<~RUBY)
      class UsersController < ApplicationController
        def show
          render layout: "form"
        end
      end
    RUBY

    refute_includes unused_names(scanner_for), "users/form"
  end

  # Negative: render layout: "users/form" does NOT mark a different partial
  # (users/other) as used.
  #
  def test_render_layout_does_not_mark_different_partial
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/_other.html.erb", "<div></div>")
    File.write("app/views/users/new.html.erb", '<%= render layout: "users/form" do %><% end %>')

    assert_includes unused_names(scanner_for), "users/other"
  end

  # Multiple renders on one line should all be detected
  #
  def test_detects_multiple_renders_on_one_line
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/_sidebar.html.erb", "<aside></aside>")
    File.write("app/views/users/index.html.erb", '<%= render "users/form" %> <%= render "users/sidebar" %>')

    refute_includes unused_names(scanner_for), "users/form"
    refute_includes unused_names(scanner_for), "users/sidebar"
  end
end
