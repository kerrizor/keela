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

# Argument-matching usage detection: the render METHOD is intentionally ignored.
# A partial is used when its ARGUMENT appears as partial:/layout: "x/y" or as a
# positional path with an explicit leading-underscore basename.
#
class PartialsUsageRegexTest < Minitest::Test
  def setup
    @strategy = Keela::Strategies::Partials.new
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

  # layout: renders the partial as a layout, so it counts as a use.
  #
  def test_matches_render_layout_double_quotes
    regex = @strategy.usage_regex("users/form")
    assert_match regex, 'render layout: "users/form"'
  end

  def test_matches_render_layout_single_quotes
    regex = @strategy.usage_regex("users/form")
    assert_match regex, "render layout: 'users/form'"
  end

  # Method-agnostic: partial: with ANY (or no) leading method still matches.
  #
  def test_matches_partial_option_with_non_render_method
    regex = @strategy.usage_regex("users/form")
    assert_match regex, 'foo(partial: "users/form")'
  end

  def test_matches_partial_option_with_no_method
    regex = @strategy.usage_regex("users/form")
    assert_match regex, 'partial: "users/form"'
  end

  # render_to_string / render_to_body use the key form too and must match.
  #
  def test_matches_render_to_string_partial_option
    regex = @strategy.usage_regex("users/form")
    assert_match regex, 'render_to_string partial: "users/form"'
  end

  def test_matches_render_to_body_partial_option
    regex = @strategy.usage_regex("users/form")
    assert_match regex, 'render_to_body(partial: "users/form")'
  end

  # Full arg-matching: a bare positional slash-path string names the partial,
  # regardless of the method (render, a custom helper, or none). Empirically,
  # quoted "a/b" strings in the scanned dirs are essentially always renders, so
  # matching the argument directly costs ~0 false negatives.
  #
  def test_matches_positional_slash_path_via_render
    regex = @strategy.usage_regex("users/form")
    assert_match regex, 'render "users/form"'
  end

  def test_matches_positional_slash_path_via_custom_method
    regex = @strategy.usage_regex("users/form")
    assert_match regex, 'some_helper("users/form")'
  end

  def test_matches_positional_slash_path_bare
    regex = @strategy.usage_regex("users/form")
    assert_match regex, '"users/form"'
  end

  # A bareword (no slash) positional string is still too ambiguous: any string
  # literal could be anything. usage_regex only matches names that contain a
  # slash; single-segment names are resolved (with a directory) via
  # #additional_used_names key forms instead.
  #
  def test_does_not_match_bareword_positional_string
    regex = @strategy.usage_regex("form")
    refute_match regex, '"form"'
    refute_match regex, 't("form")'
  end

  def test_does_not_match_different_partial
    regex = @strategy.usage_regex("users/form")
    refute_match regex, 'render partial: "users/sidebar"'
  end

  # Substring safety: "users/form" must not match "users/form_wrapper".
  #
  def test_does_not_match_substring_partial
    regex = @strategy.usage_regex("users/form")
    refute_match regex, 'render partial: "users/form_wrapper"'
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

  def test_handles_ee_partials
    FileUtils.mkdir_p("ee/app/views/users")
    File.write("ee/app/views/users/_unused.html.erb", "<div>ee dead</div>")

    scanner = scanner_for(patterns: %w[ee/app/**/*.erb app/**/*.rb], extensions: %w[erb rb])
    assert_includes unused_names(scanner), "users/unused"
  end

  # Key form with an explicit path marks the partial used.
  #
  def test_does_not_flag_used_partial_via_partial_option
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/index.html.erb", '<%= render partial: "users/form" %>')

    refute_includes unused_names(scanner_for), "users/form"
  end

  # ARG-MATCHING WIN: partial: "x/y" with NO render token in sight is used.
  #
  def test_detects_partial_option_without_render_token
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/index.html.erb", '<%= foo(partial: "users/form") %>')

    refute_includes unused_names(scanner_for), "users/form"
  end

  # ARG-MATCHING WIN: a multi-line call with partial: on its own line is caught,
  # regardless of the method name on the opening line.
  #
  def test_detects_multiline_partial_option
    FileUtils.mkdir_p("app/views/shared")
    FileUtils.mkdir_p("app/controllers")
    File.write("app/views/shared/_thing.html.erb", "<div></div>")
    File.write("app/controllers/things_controller.rb", <<~RUBY)
      class ThingsController < ApplicationController
        def show
          render_to_string(
            formats: [:html],
            partial: "shared/thing"
          )
        end
      end
    RUBY

    refute_includes unused_names(scanner_for), "shared/thing"
  end

  # ARG-MATCHING WIN: a positional underscore path via a NON-render custom helper
  # (view_to_html_string) is caught. shared/notes/_note -> shared/notes/note.
  #
  def test_detects_positional_underscore_path_via_custom_helper
    FileUtils.mkdir_p("app/views/shared/notes")
    FileUtils.mkdir_p("app/controllers")
    File.write("app/views/shared/notes/_note.html.erb", "<div></div>")
    File.write("app/controllers/notes_controller.rb", <<~RUBY)
      class NotesController < ApplicationController
        def show
          view_to_html_string("shared/notes/_note")
        end
      end
    RUBY

    refute_includes unused_names(scanner_for), "shared/notes/note"
  end

  # ARG-MATCHING WIN: tabs_json custom helper with a positional underscore path.
  #
  def test_detects_positional_underscore_path_via_tabs_json
    FileUtils.mkdir_p("app/views/shared/milestones")
    FileUtils.mkdir_p("app/controllers")
    File.write("app/views/shared/milestones/_issues_tab.html.erb", "<div></div>")
    File.write("app/controllers/milestones_controller.rb", <<~RUBY)
      class MilestonesController < ApplicationController
        def show
          tabs_json("shared/milestones/_issues_tab")
        end
      end
    RUBY

    refute_includes unused_names(scanner_for), "shared/milestones/issues_tab"
  end

  # Positional underscore path via render_to_string keeps working.
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

  # Positional underscore path via plain render.
  #
  def test_detects_positional_underscore_path_plain_render
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/index.html.erb", '<%= render "users/_form" %>')

    refute_includes unused_names(scanner_for), "users/form"
  end

  # Relative (bareword) key-form render from a sibling view -> users/form.
  #
  def test_detects_relative_partial_option_from_sibling_view
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/show.html.erb", '<%= render partial: "form" %>')

    refute_includes unused_names(scanner_for), "users/form"
  end

  # Relative bareword key-form render from a controller -> users/form.
  #
  def test_detects_relative_partial_option_from_controller
    FileUtils.mkdir_p("app/views/users")
    FileUtils.mkdir_p("app/controllers")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/controllers/users_controller.rb", <<~RUBY)
      class UsersController < ApplicationController
        def show
          render partial: "form"
        end
      end
    RUBY

    refute_includes unused_names(scanner_for), "users/form"
  end

  # Nested controller: admin/users_controller.rb -> admin/users/form.
  #
  def test_detects_relative_partial_option_from_nested_controller
    FileUtils.mkdir_p("app/views/admin/users")
    FileUtils.mkdir_p("app/controllers/admin")
    File.write("app/views/admin/users/_form.html.erb", "<form></form>")
    File.write("app/controllers/admin/users_controller.rb", <<~RUBY)
      class Admin::UsersController < ApplicationController
        def show
          render layout: "form"
        end
      end
    RUBY

    refute_includes unused_names(scanner_for), "admin/users/form"
  end

  # Bareword layout: key from a sibling view -> users/form.
  #
  def test_detects_relative_layout_option_from_sibling_view
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/show.html.erb", '<%= render layout: "form" do %><% end %>')

    refute_includes unused_names(scanner_for), "users/form"
  end

  # layout: with an explicit path marks the partial used.
  #
  def test_detects_layout_option_explicit_path
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/new.html.erb", '<%= render layout: "users/form" do %><% end %>')

    refute_includes unused_names(scanner_for), "users/form"
  end

  # DECISION: dynamic render with a variable is statically unsolvable, so the
  # partial is (correctly) reported unused rather than guessed-at.
  #
  def test_does_not_resolve_dynamic_render
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/index.html.erb", "<%= render partial_name %>")

    assert_includes unused_names(scanner_for), "users/form"
  end

  # DECISION: collection/object render is a documented limitation, not
  # implemented. render @users does NOT mark users/user used.
  #
  def test_does_not_resolve_collection_render
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_user.html.erb", "<li></li>")
    File.write("app/views/users/index.html.erb", "<%= render @users %>")

    assert_includes unused_names(scanner_for), "users/user"
  end

  # SAFETY: substring guard. partial: "users/form" does NOT mark
  # users/form_wrapper used.
  #
  def test_does_not_match_substring_partials
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/_form_wrapper.html.erb", "<div></div>")
    File.write("app/views/users/index.html.erb", '<%= render partial: "users/form" %>')

    refute_includes unused_names(scanner_for), "users/form"
    assert_includes unused_names(scanner_for), "users/form_wrapper"
  end

  # ARG-MATCHING WIN: a positional slash-path string marks the partial used even
  # from a non-render custom helper. This is the common GitLab view form
  # (render "shared/foo") and the reason arg-matching flags strictly fewer
  # partials than the method-anchored branch.
  #
  def test_positional_slash_path_marks_used_via_custom_method
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/index.html.erb", '<%= some_helper("users/form") %>')

    refute_includes unused_names(scanner_for), "users/form"
  end

  # ARG-MATCHING WIN: the classic positional render form (no partial: key).
  #
  def test_positional_slash_path_marks_used_via_render
    FileUtils.mkdir_p("app/views/shared")
    FileUtils.mkdir_p("app/views/dashboard")
    File.write("app/views/shared/_header.html.erb", "<div></div>")
    File.write("app/views/dashboard/index.html.erb", '<%= render "shared/header" %>')

    refute_includes unused_names(scanner_for), "shared/header"
  end

  # SAFETY: a single-segment bareword positional string (no slash, no key, no
  # underscore) is too ambiguous, so it does NOT mark a partial used. A
  # genuinely-dead partial referenced only this way stays flagged.
  #
  def test_bareword_positional_string_not_matched
    FileUtils.mkdir_p("app/views/users")
    FileUtils.mkdir_p("app/views/other")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/other/index.html.erb", '<%= t("form") %>')

    assert_includes unused_names(scanner_for), "users/form"
  end

  # skip_comments? only governs DEFINITION extraction (the scanner strips
  # leading-# lines before extracting), not usage detection: usage_regex and the
  # #additional_used_names scan run against the raw joined source. So a
  # commented-out render:  # render partial: "users/form"  DOES mark the partial
  # used. This mirrors the method-anchored branch's honest behavior and is
  # documented as a minor limitation rather than special-cased.
  #
  def test_commented_render_is_still_treated_as_usage
    FileUtils.mkdir_p("app/views/users")
    FileUtils.mkdir_p("app/controllers")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/controllers/users_controller.rb", <<~RUBY)
      class UsersController < ApplicationController
        # render partial: "users/form" -- commented out, still counted as usage
        def show
        end
      end
    RUBY

    refute_includes unused_names(scanner_for), "users/form"
  end

  # SAFETY: plain prose with no partial:/layout: key and no underscore path does
  # NOT mark anything used.
  #
  def test_plain_prose_does_not_mark_used
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/index.html.erb", "<%# just a note about the users form %>")

    assert_includes unused_names(scanner_for), "users/form"
  end

  # FIX 1: a partial directly under app/views/ (no intermediate dir) must be
  # picked up by the file-pattern filter during a full scan. A genuinely-dead
  # root partial IS reported unused.
  #
  def test_detects_unused_root_level_partial
    FileUtils.mkdir_p("app/views")
    File.write("app/views/_foo.html.erb", "<div>never rendered</div>")

    assert_includes unused_names(scanner_for), "foo"
  end

  # FIX 1: a root-level partial rendered via a bareword key form from a
  # root-level view is not flagged (caller dir "").
  #
  def test_does_not_flag_used_root_level_partial
    FileUtils.mkdir_p("app/views")
    File.write("app/views/_foo.html.erb", "<div>rendered</div>")
    File.write("app/views/index.html.erb", '<%= render partial: "foo" %>')

    refute_includes unused_names(scanner_for), "foo"
  end

  # Multiple key-form renders on one line are all detected.
  #
  def test_detects_multiple_partial_options_on_one_line
    FileUtils.mkdir_p("app/views/users")
    File.write("app/views/users/_form.html.erb", "<form></form>")
    File.write("app/views/users/_sidebar.html.erb", "<aside></aside>")
    File.write(
      "app/views/users/index.html.erb",
      '<%= render partial: "users/form" %> <%= render partial: "users/sidebar" %>'
    )

    refute_includes unused_names(scanner_for), "users/form"
    refute_includes unused_names(scanner_for), "users/sidebar"
  end
end
