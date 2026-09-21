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

  # A left word-boundary keeps prerender/foo_render from counting as a render of
  # this partial (e.g. prerender "users/form" is not a render of users/form).
  #
  def test_does_not_match_prefixed_render_word
    regex = @strategy.usage_regex("users/form")
    refute_match regex, 'prerender "users/form"'
    refute_match regex, 'foo_render "users/form"'
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

  # render_to_string / render_to_body render partials too, in both the
  # no-parens same-line form and the contiguous parens form.
  #
  def test_matches_render_to_string_no_parens
    regex = @strategy.usage_regex("users/form")
    assert_match regex, 'render_to_string partial: "users/form"'
  end

  def test_matches_render_to_string_parens_contiguous
    regex = @strategy.usage_regex("users/form")
    assert_match regex, 'render_to_string(partial: "users/form")'
  end

  def test_matches_render_to_body_no_parens
    regex = @strategy.usage_regex("users/form")
    assert_match regex, 'render_to_body partial: "users/form"'
  end

  def test_matches_render_to_body_parens_contiguous
    regex = @strategy.usage_regex("users/form")
    assert_match regex, 'render_to_body(partial: "users/form")'
  end

  def test_matches_render_to_string_plain_string
    regex = @strategy.usage_regex("users/form")
    assert_match regex, 'render_to_string "users/form"'
  end

  # The left word-boundary must still reject method tokens that merely end in
  # render_to_string / render_to_body.
  #
  def test_does_not_match_suffixed_render_to_string
    regex = @strategy.usage_regex("users/form")
    refute_match regex, 'foo_render_to_string partial: "users/form"'
  end

  def test_does_not_match_prerender_still
    regex = @strategy.usage_regex("users/form")
    refute_match regex, 'prerender "users/form"'
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

  # FIX 1: a partial directly under app/views/ (no intermediate dir) must be
  # picked up by the file-pattern filter during a full scan, not just by a direct
  # call to #extract_definitions_from_file. A genuinely-dead root partial IS
  # reported unused.
  #
  def test_detects_unused_root_level_partial
    FileUtils.mkdir_p("app/views")
    File.write("app/views/_foo.html.erb", "<div>never rendered</div>")

    assert_includes unused_names(scanner_for), "foo"
  end

  # FIX 1: a root-level partial that IS rendered by an explicit path from a
  # root-level view is not flagged. render "foo" in app/views/index.html.erb
  # resolves to the root-level "foo" via bareword resolution (caller dir "").
  #
  def test_does_not_flag_used_root_level_partial
    FileUtils.mkdir_p("app/views")
    File.write("app/views/_foo.html.erb", "<div>rendered</div>")
    File.write("app/views/index.html.erb", '<%= render "foo" %>')

    refute_includes unused_names(scanner_for), "foo"
  end

  # FIX 2: a left word-boundary on the render pattern prevents prerender from
  # marking a partial used via explicit path. prerender "users/form" is NOT a
  # render of users/form, so the partial stays unused.
  #
  def test_prerender_does_not_mark_explicit_path_used
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/index.html.erb", '<%= prerender "users/form" %>')

    assert_includes unused_names(scanner_for), "users/form"
  end

  # FIX 2: the same left-boundary applies to bareword resolution. foo_render
  # "form" in a sibling view is NOT a render of users/form.
  #
  def test_suffixed_render_does_not_mark_bareword_used
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/show.html.erb", '<%= foo_render "form" %>')

    assert_includes unused_names(scanner_for), "users/form"
  end

  # FIX 2 positive control: a plain render "users/form" still marks the partial
  # used after the left-boundary is added.
  #
  def test_plain_render_still_marks_used
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/index.html.erb", '<%= render "users/form" %>')

    refute_includes unused_names(scanner_for), "users/form"
  end

  # render_to_string with an explicit partial: path marks the partial used,
  # matching the GitLab false positive render_to_string(partial: '...').
  #
  def test_detects_render_to_string_explicit_path
    FileUtils.mkdir_p("app/views/users")
    FileUtils.mkdir_p("app/controllers")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/controllers/users_controller.rb", <<~RUBY)
      class UsersController < ApplicationController
        def show
          render_to_string(partial: "users/form")
        end
      end
    RUBY

    refute_includes unused_names(scanner_for), "users/form"
  end

  # render_to_body is also a render method.
  #
  def test_detects_render_to_body_explicit_path
    FileUtils.mkdir_p("app/views/users")
    FileUtils.mkdir_p("app/controllers")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/controllers/users_controller.rb", <<~RUBY)
      class UsersController < ApplicationController
        def show
          render_to_body partial: "users/form"
        end
      end
    RUBY

    refute_includes unused_names(scanner_for), "users/form"
  end

  # A bareword render_to_string resolves against the caller dir just like
  # render, matching render_to_string partial: 'groups_notification'.
  #
  def test_detects_render_to_string_bareword_from_controller
    FileUtils.mkdir_p("app/views/users")
    FileUtils.mkdir_p("app/controllers")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/controllers/users_controller.rb", <<~RUBY)
      class UsersController < ApplicationController
        def show
          render_to_string partial: "form"
        end
      end
    RUBY

    refute_includes unused_names(scanner_for), "users/form"
  end

  # foo_render_to_string is not a render method; the left word-boundary keeps it
  # from marking the partial used.
  #
  def test_suffixed_render_to_string_does_not_mark_used
    FileUtils.mkdir_p("app/views/users")
    FileUtils.mkdir_p("app/controllers")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/controllers/users_controller.rb", <<~RUBY)
      class UsersController < ApplicationController
        def show
          foo_render_to_string partial: "users/form"
        end
      end
    RUBY

    assert_includes unused_names(scanner_for), "users/form"
  end

  # A positional string whose basename starts with _ names the partial file
  # directly. render_to_string("shared/notes/_note") uses shared/notes/note.
  #
  def test_detects_positional_underscore_path_render_to_string
    FileUtils.mkdir_p("app/views/shared/notes")
    FileUtils.mkdir_p("app/controllers")
    File.write("app/views/shared/notes/_note.html.erb", "<div></div>")
    File.write("app/controllers/notes_controller.rb", <<~RUBY)
      class NotesController < ApplicationController
        def show
          render_to_string("shared/notes/_note", locals: {})
        end
      end
    RUBY

    refute_includes unused_names(scanner_for), "shared/notes/note"
  end

  # The positional-underscore form also works through plain render.
  #
  def test_detects_positional_underscore_path_plain_render
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/index.html.erb", '<%= render "users/_form" %>')

    refute_includes unused_names(scanner_for), "users/form"
  end

  # A positional string without a leading underscore in the basename still
  # resolves through the existing explicit-path matcher and must not break.
  #
  def test_plain_positional_path_without_underscore_still_used
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/index.html.erb", '<%= render "users/form" %>')

    refute_includes unused_names(scanner_for), "users/form"
  end

  # A positional VARIABLE render is dynamic and stays undetected: the partial
  # is (correctly) reported unused rather than guessed-at.
  #
  def test_does_not_resolve_positional_variable_render_to_string
    FileUtils.mkdir_p("app/views/users")
    FileUtils.mkdir_p("app/controllers")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/controllers/users_controller.rb", <<~RUBY)
      class UsersController < ApplicationController
        def show
          render_to_string(some_var)
        end
      end
    RUBY

    assert_includes unused_names(scanner_for), "users/form"
  end
end

class PartialsRenderHelpersTest < Minitest::Test
  def setup
    Keela.reset_configuration!
    @tmpdir = Dir.mktmpdir
    @original_dir = Dir.pwd
    Dir.chdir(@tmpdir)
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@tmpdir)
    Keela.reset_configuration!
  end

  def configure_helpers(*helpers)
    Keela.configuration.strategy_options = {
      "partials" => { "render_helpers" => helpers }
    }
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

  # A configured helper called with a positional full path marks that partial
  # used, matching GitLab's view_to_html_string("projects/blob/_viewer").
  #
  def test_configured_helper_positional_path_marks_used
    configure_helpers("view_to_html_string")
    FileUtils.mkdir_p("app/views/projects/blob")
    File.write("app/views/projects/blob/_viewer.html.erb", "<div></div>")
    File.write("app/views/projects/blob/show.html.erb", '<%= view_to_html_string("projects/blob/_viewer") %>')

    refute_includes unused_names(scanner_for), "projects/blob/viewer"
  end

  # A configured helper resolves positional-underscore paths the same way render
  # does: helper("a/_b") -> a/b.
  #
  def test_configured_helper_positional_underscore_marks_used
    configure_helpers("view_to_html_string")
    FileUtils.mkdir_p("app/views/a")
    File.write("app/views/a/_b.html.erb", "<div></div>")
    File.write("app/views/a/index.html.erb", '<%= view_to_html_string("a/_b") %>')

    refute_includes unused_names(scanner_for), "a/b"
  end

  # A configured helper honors the partial:/layout: keyword form too, matching
  # render's explicit-path handling (the standard Rails partial: form uses the
  # logical name without the leading underscore).
  #
  def test_configured_helper_partial_key_marks_used
    configure_helpers("tabs_json")
    FileUtils.mkdir_p("app/views/shared/milestones")
    File.write("app/views/shared/milestones/_tab.html.erb", "<div></div>")
    File.write("app/views/shared/milestones/index.html.erb", '<%= tabs_json(partial: "shared/milestones/tab") %>')

    refute_includes unused_names(scanner_for), "shared/milestones/tab"
  end

  # A helper name containing regex metacharacters is matched literally, so
  # foo.bar("x/y") matches but fooXbar("x/y") does not.
  #
  def test_configured_helper_name_metacharacters_are_literal
    configure_helpers("foo.bar")
    FileUtils.mkdir_p("app/views/x")
    File.write("app/views/x/_y.html.erb", "<div></div>")
    File.write("app/views/x/_z.html.erb", "<div></div>")
    File.write("app/views/x/index.html.erb", <<~ERB)
      <%= foo.bar("x/_y") %>
      <%= fooXbar("x/_z") %>
    ERB

    names = unused_names(scanner_for)
    refute_includes names, "x/y"
    assert_includes names, "x/z"
  end

  # An UNconfigured helper is ignored: other_helper("a/b") does not mark a/b.
  #
  def test_unconfigured_helper_is_ignored
    configure_helpers("view_to_html_string")
    FileUtils.mkdir_p("app/views/a")
    File.write("app/views/a/_b.html.erb", "<div></div>")
    File.write("app/views/a/index.html.erb", '<%= other_helper("a/_b") %>')

    assert_includes unused_names(scanner_for), "a/b"
  end

  # The key safety guarantee: a configured helper NEVER enables bareword-relative
  # resolution. view_to_html_string("form") (no slash) must NOT resolve to
  # caller_dir/form the way render "form" would.
  #
  def test_configured_helper_bareword_does_not_resolve
    configure_helpers("view_to_html_string")
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/show.html.erb", '<%= view_to_html_string("form") %>')

    assert_includes unused_names(scanner_for), "users/form"
  end

  # The left word-boundary applies to configured helpers: a prefixed token like
  # my_tabs_json("a/b") is not the configured tabs_json helper.
  #
  def test_prefixed_configured_helper_is_rejected
    configure_helpers("tabs_json")
    FileUtils.mkdir_p("app/views/a")
    File.write("app/views/a/_b.html.erb", "<div></div>")
    File.write("app/views/a/index.html.erb", '<%= my_tabs_json("a/_b") %>')

    assert_includes unused_names(scanner_for), "a/b"
  end

  # Regression: with NO render_helpers configured, a plain render "a/b" still
  # marks the partial used (default behavior is unchanged).
  #
  def test_no_helpers_configured_plain_render_still_works
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/index.html.erb", '<%= render "users/form" %>')

    refute_includes unused_names(scanner_for), "users/form"
  end

  # Regression: with NO render_helpers configured, a custom helper is NOT
  # recognized, so its target partial stays unused.
  #
  def test_no_helpers_configured_custom_helper_not_recognized
    FileUtils.mkdir_p("app/views/a")
    File.write("app/views/a/_b.html.erb", "<div></div>")
    File.write("app/views/a/index.html.erb", '<%= view_to_html_string("a/_b") %>')

    assert_includes unused_names(scanner_for), "a/b"
  end

  # Multiple helpers configured at once (the realistic common config): a partial
  # rendered via one helper AND a different partial rendered via another are
  # both recognized as used in the same run.
  #
  def test_multiple_configured_helpers_all_recognized
    configure_helpers("view_to_html_string", "tabs_json")
    FileUtils.mkdir_p("app/views/projects/blob")
    FileUtils.mkdir_p("app/views/shared/milestones")
    File.write("app/views/projects/blob/_viewer.html.erb", "<div></div>")
    File.write("app/views/shared/milestones/_issues_tab.html.erb", "<div></div>")
    File.write("app/views/projects/blob/show.html.erb", '<%= view_to_html_string("projects/blob/_viewer") %>')
    File.write("app/views/shared/milestones/index.html.erb", '<%= tabs_json("shared/milestones/_issues_tab") %>')

    names = unused_names(scanner_for)
    refute_includes names, "projects/blob/viewer"
    refute_includes names, "shared/milestones/issues_tab"
  end

  # A configured helper tolerates the same whitespace/paren variations as base
  # render (RENDER_METHOD's \s*\(?\s* tail): a space before the paren, a newline
  # inside the parens, and the no-parens form all resolve the partial.
  #
  def test_configured_helper_whitespace_and_paren_variations
    configure_helpers("view_to_html_string")
    FileUtils.mkdir_p("app/views/projects/blob")
    File.write("app/views/projects/blob/_viewer.html.erb", "<div></div>")
    File.write("app/views/projects/blob/space_paren.html.erb", '<%= view_to_html_string ("projects/blob/_viewer") %>')
    File.write("app/views/projects/blob/newline.html.erb", <<~ERB)
      <%= view_to_html_string(
        "projects/blob/_viewer"
      ) %>
    ERB
    File.write("app/views/projects/blob/no_parens.html.erb", '<%= view_to_html_string "projects/blob/_viewer" %>')

    refute_includes unused_names(scanner_for), "projects/blob/viewer"
  end
end

class PartialsERBCommentsTest < Minitest::Test
  def setup
    Keela.reset_configuration!
    @tmpdir = Dir.mktmpdir
    @original_dir = Dir.pwd
    Dir.chdir(@tmpdir)
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@tmpdir)
    Keela.reset_configuration!
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

  def test_explicit_render_in_erb_comment_does_not_mark_used
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_old_form.html.erb", "<form></form>")
    File.write("app/views/users/index.html.erb", '<%# render "users/old_form" %>')

    assert_includes unused_names(scanner_for), "users/old_form"
  end

  def test_render_in_erb_comment_trim_variants_ignored
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_left.html.erb", "<form></form>")
    File.write("app/views/users/_right.html.erb", "<form></form>")
    File.write("app/views/users/index.html.erb", <<~ERB)
      <%-# render "users/left" %>
      <%# render "users/right" -%>
    ERB

    names = unused_names(scanner_for)
    assert_includes names, "users/left"
    assert_includes names, "users/right"
  end

  # Only the comment tag is stripped, so a real render sharing the line survives.
  #
  def test_real_render_same_line_as_comment_still_counts
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/_old.html.erb", "<form></form>")
    File.write("app/views/users/index.html.erb", '<%= render "users/form" %> <%# render "users/old" %>')

    names = unused_names(scanner_for)
    refute_includes names, "users/form"
    assert_includes names, "users/old"
  end

  # A <%= output %> tag has = not # after <%, so it must not be stripped.
  #
  def test_output_tag_render_still_counts
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/index.html.erb", '<%= render "users/form" %>')

    refute_includes unused_names(scanner_for), "users/form"
  end

  # A <% code %> tag has no # after <%, so it must not be stripped.
  #
  def test_code_tag_render_still_counts
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/index.html.erb", '<% render "users/form" %>')

    refute_includes unused_names(scanner_for), "users/form"
  end

  # Stripping must also cover the bareword-resolution path.
  #
  def test_bareword_render_in_erb_comment_does_not_resolve
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/show.html.erb", '<%# render "form" %>')

    assert_includes unused_names(scanner_for), "users/form"
  end

  # Stripping must also cover the positional-underscore path.
  #
  def test_positional_underscore_render_in_erb_comment_does_not_mark_used
    FileUtils.mkdir_p("app/views/shared/notes")
    File.write("app/views/shared/notes/_note.html.erb", "<div></div>")
    File.write("app/views/shared/notes/index.html.erb", '<%# render "shared/notes/_note" %>')

    assert_includes unused_names(scanner_for), "shared/notes/note"
  end

  # Out of scope: single-line stripping does not cross newlines, so a render in
  # a multi-line ERB comment is still counted.
  #
  def test_multiline_erb_comment_render_is_still_counted
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/index.html.erb", <<~ERB)
      <%#
        render "users/form"
      %>
    ERB

    refute_includes unused_names(scanner_for), "users/form"
  end

  # Out of scope: HAML comments are not stripped, so a render in a HAML comment
  # is still counted.
  #
  def test_haml_comment_render_is_still_counted
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.haml", "%form")
    File.write("app/views/users/index.html.haml", '-# = render "users/form"')

    scanner = scanner_for(patterns: %w[app/**/*.haml], extensions: %w[haml])
    refute_includes unused_names(scanner), "users/form"
  end
end
