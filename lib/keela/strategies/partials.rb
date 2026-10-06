# frozen_string_literal: true

module Keela
  module Strategies
    # Detects unused Rails view partials (_*.html.{erb,haml,slim}) under
    # app/views/** and ee/app/views/**.
    #
    # Definitions come from filenames, not file contents (like i18n_keys), so
    # this strategy overrides #extract_definitions_from_file. The logical name
    # is the path with the app/views/ (or ee/app/views/) prefix, leading _, and
    # extension stripped: app/views/users/_form.html.erb -> "users/form".
    #
    # Usage is detected two ways:
    #   1. Explicit paths via #usage_regex: render "users/form",
    #      render partial: "users/form", render layout: "users/form". layout:
    #      renders a partial as a layout, so it counts as a use.
    #   2. Relative (bareword) renders via #additional_used_names: render "form"
    #      (and render partial:/layout: "form") is resolved against the CALLING
    #      file's directory. In a view, the directory is the view's own dir; in a
    #      controller, it is derived from the controller name
    #      (users_controller.rb -> users).
    #
    # Known limitations (not implemented, by design):
    #   - Collection/object render (render @users -> users/_user) is NOT
    #     resolved. A singularize heuristic could silently hide dead code on a
    #     wrong guess, so these partials may be reported as unused; suppress via
    #     the baseline.
    #   - Dynamic render with a variable (render partial_name) is statically
    #     unsolvable, so it is not resolved (same posture as send for methods).
    #   - shared/* partials are treated like any other partial; false positives
    #     belong in the baseline rather than a hard-coded skip.
    #
    class Partials < Strategy
      # The intermediate directory is optional so a partial directly under
      # app/views/ (app/views/_foo.html.erb) matches too; without this the file
      # filter and #extract_definitions_from_file disagree and root partials are
      # silently skipped.
      #
      DEFINITION_FILE_REGEX = %r{(?:ee/)?app/views/(?:.*/)?_[^/]+\.html\.(?:erb|haml|slim)$}.freeze

      # Captures the path under app/views/ so we can derive a partial name:
      # app/views/users/_form.html.erb -> "users/_form"
      #
      NAME_PATH_REGEX = %r{(?:ee/)?app/views/(.+)\.html\.(?:erb|haml|slim)$}.freeze

      # The directory of a calling VIEW, used to resolve bareword renders.
      # app/views/users/show.html.erb -> "users"
      #
      VIEW_DIR_REGEX = %r{(?:ee/)?app/views/(.+)/[^/]+\.html\.(?:erb|haml|slim)$}.freeze

      # A controller path, used to derive the implicit view directory for
      # bareword renders made from controllers.
      # app/controllers/users_controller.rb -> "users"
      # app/controllers/admin/users_controller.rb -> "admin/users"
      #
      CONTROLLER_REGEX = %r{(?:ee/)?app/controllers/(.+)_controller\.rb$}.freeze

      # A view directly under app/views/ with no intermediate directory, e.g.
      # app/views/index.html.erb. Its caller directory is the root (""), so a
      # bareword render "foo" from here resolves to the root-level partial "foo".
      # VIEW_DIR_REGEX requires an intermediate dir and so never matches these.
      #
      ROOT_VIEW_REGEX = %r{(?:ee/)?app/views/[^/]+\.html\.(?:erb|haml|slim)$}.freeze

      # The render family we recognize: render, plus render_to_string and
      # render_to_body, which render partials the same way (Rails/GitLab use both
      # off-request, e.g. in mailers and background jobs). An optional opening
      # paren after the method lets us match both the no-parens same-line form
      # (render_to_string partial: "x/y") and the contiguous parens form
      # (render_to_string(partial: "x/y")). Multi-line detached partial: args are
      # out of scope; see issue #84.
      #
      RENDER_METHOD = /render(?:_to_string|_to_body)?\s*\(?\s*/

      # A bareword render: render "form" / render 'form' / render partial: "form"
      # / render layout: "form". layout: renders a partial as a layout, so it
      # counts as a use just like partial:. Only barewords (no slash) are
      # captured here; paths with a slash are handled by #usage_regex.
      #
      # The leading negative lookbehind anchors the method on its left so that
      # prerender/foo_render(_to_string) do not count as a render.
      #
      # This uses RENDER_METHOD, not #render_method_pattern, on purpose:
      # configured render_helpers must never enable bareword-relative resolution.
      # A bare 'form' passed to an arbitrary app helper is too ambiguous to
      # safely resolve against the caller's directory.
      #
      BAREWORD_RENDER_REGEX = /(?<!\w)#{RENDER_METHOD}(?:(?:partial|layout):\s*)?["']([^"'\/]+)["']/

      def name
        "partials"
      end

      def default_definition_file_pattern
        DEFINITION_FILE_REGEX
      end

      # Definitions come from filenames, not contents.
      def extract_definitions_from_file(filepath, _lines)
        return [] unless filepath =~ NAME_PATH_REGEX

        # "users/_form" -> "users/form"; "_form" -> "form"
        name = Regexp.last_match(1).sub(%r{(^|/)_}, '\1')

        [{ name: name, file: filepath }]
      end

      def extract_definition(_line)
        # Not used; definitions come from #extract_definitions_from_file.
        nil
      end

      def usage_regex(name)
        # render "users/form", render 'users/form',
        # render partial: "users/form", render layout: "users/form"
        # (single/double quotes, tolerant space). layout: renders the partial as
        # a layout, so it counts as a use. render_to_string / render_to_body are
        # recognized too via RENDER_METHOD.
        #
        # The leading negative lookbehind anchors the method on its left so that
        # prerender/foo_render do not count as a render.
        #
        # Configured render_helpers extend the method token here (explicit-path
        # matching only) via #render_method_pattern.
        #
        /(?<!\w)#{render_method_pattern}(?:(?:partial|layout):\s*)?["']#{Regexp.quote(name)}["']/
      end

      def skip_comments?
        true
      end

      # #additional_used_names collects every rendered partial name in a single
      # pass, so the scanner decides by Set membership and skips the per-definition
      # #used? scan. See the note on #additional_used_names.
      #
      def detects_all_usage?
        true
      end

      # Build the comment-stripped view once in the parent so workers inherit it
      # copy-on-write instead of each rebuilding a codebase-sized string.
      #
      def prepare(source)
        @stripped_source = source
        @stripped_text = strip_erb_comments(source.text)
      end

      # Match against a view with single-line ERB comments removed, so a render
      # inside <%# ... %> does not count as a usage. Falls back to stripping on
      # demand if #prepare was not run for this source (defensive: #used? can be
      # called directly in tests, or on a different source than #prepare saw).
      #
      # Retained as the Strategy contract and for direct callers (tests), but the
      # scanner no longer drives detection through it: #additional_used_names now
      # collects every used name in a single pass over the corpus, so the scanner
      # decides via that Set instead of calling #used? per definition. See the
      # note on #additional_used_names.
      #
      def used?(name, source)
        usage_regex(name).match?(stripped_text_for(source))
      end

      # The set of partial names used anywhere in +source_files+, collected in a
      # SINGLE pass over the corpus.
      #
      # This is the whole-run detection path for partials. The scanner checks a
      # definition against this Set and never calls #used? for a name that is in
      # it, so extracting every used name here (not just the bareword/positional
      # ones) turns detection from O(N_partials x codebase) per-definition regex
      # scans into O(codebase + N_partials): we scan each file once, collect the
      # rendered names, then membership-test each definition. This is the fix for
      # the partials strategy being CPU-bound on large codebases.
      #
      # Three render forms are collected, each the single-pass twin of a branch
      # that used to be matched per-definition:
      #
      #   1. Explicit slashed paths (the #usage_regex cases): render "users/form",
      #      render partial:/layout: "users/form", render_to_string/_to_body, and
      #      configured render_helpers. Captured verbatim as the logical name.
      #   2. Positional-underscore paths: render "shared/notes/_note" names the
      #      file directly -> "shared/notes/note" (strip the basename's leading _).
      #   3. Barewords resolved against the caller's directory: render "form" in
      #      app/views/users/* or users_controller.rb -> "users/form".
      #
      # All three share the comment-stripped content and the same left word-anchor
      # and render-method rules as #usage_regex, so the collected strings are
      # exactly what the per-name regex would have matched.
      #
      def additional_used_names(source_files)
        used = Set.new

        source_files.each do |filepath, lines|
          content = strip_erb_comments(lines.join("\n"))

          # Explicit slashed paths: the single-pass twin of #usage_regex. A
          # basename leading _ is stripped so "users/_form" and "users/form"
          # agree with the positional-underscore form and with definition names.
          #
          content.scan(explicit_path_regex).each do |(path)|
            used << path.sub(%r{(^|/)_([^/]+)$}, '\1\2')
          end

          # Positional-underscore paths are absolute logical names, so they are
          # resolved regardless of the caller's directory. "shared/notes/_note"
          # -> "shared/notes/note" (strip the leading _ of the basename only).
          #
          content.scan(positional_underscore_regex).each do |(path)|
            used << path.sub(%r{/_([^/]+)$}, '/\1')
          end

          dir = caller_directory(filepath)
          next unless dir

          content.scan(BAREWORD_RENDER_REGEX).each do |(bareword)|
            # dir is "" for a root-level view, so join without a separator to
            # resolve render "foo" -> "foo" rather than "/foo".
            #
            used << (dir.empty? ? bareword : "#{dir}/#{bareword}")
          end
        end

        used
      end

      private

      # The comment-stripped text for +source+, using the view #prepare built
      # when it saw this same source, otherwise stripping on demand.
      #
      def stripped_text_for(source)
        return @stripped_text if defined?(@stripped_source) && @stripped_source.equal?(source)

        strip_erb_comments(source.text)
      end

      # Blank out single-line ERB comment tags so renders inside them are not
      # matched. Matches <% (optional -) then #, up to %> (optional -), on one
      # line; a <%= output %> or <% code %> tag has no # after <% and is left
      # intact. Multi-line ERB comments and HAML comments are out of scope: the
      # dot does not cross newlines, so they are not matched.
      #
      # Replaced with same-length spaces (via the block form, so the length is
      # the matched span's, not a global) to preserve positions and line
      # structure.
      #
      def strip_erb_comments(text)
        text.gsub(/<%\s*-?\s*#.*?-?\s*%>/) { |match| " " * match.length }
      end

      # The directory a bareword render resolves against: the view's own dir, the
      # controller-derived dir, or "" for a root-level view (render "foo" from
      # app/views/index.html.erb resolves to the root partial "foo"). Returns nil
      # for files that render nothing resolvable this way.
      #
      def caller_directory(filepath)
        return Regexp.last_match(1) if filepath =~ VIEW_DIR_REGEX
        return Regexp.last_match(1) if filepath =~ CONTROLLER_REGEX
        return "" if filepath =~ ROOT_VIEW_REGEX

        nil
      end

      # The single-pass twin of #usage_regex: instead of matching one known name,
      # CAPTURE the rendered path so one scan collects every explicitly-rendered
      # partial. Same left word-anchor, same optional partial:/layout: keyword,
      # same #render_method_pattern (so configured render_helpers are honored),
      # as #usage_regex.
      #
      # The captured path must contain at least one slash: barewords (no slash)
      # are resolved relative to the caller by #additional_used_names via
      # BAREWORD_RENDER_REGEX, exactly as #usage_regex only ever matched slashed
      # logical names. Requiring a slash here keeps the two paths disjoint.
      #
      def explicit_path_regex
        %r{(?<!\w)#{render_method_pattern}(?:(?:partial|layout):\s*)?["']([^"'/]+(?:/[^"'/]+)+)["']}
      end

      # A positional string whose basename starts with _ names a partial file
      # directly: render_to_string("shared/notes/_note") uses shared/notes/note.
      # There is no partial:/layout: keyword here, so it is handled separately
      # from #usage_regex and the bareword path. Only the leading _ of the
      # BASENAME is stripped; intermediate path segments are kept verbatim.
      #
      # A method (not a constant) so configured render_helpers extend the
      # recognized method token via #render_method_pattern.
      #
      def positional_underscore_regex
        /(?<!\w)#{render_method_pattern}["']([^"']*\/_[^"'\/]+)["']/
      end

      # The recognized render-method token for EXPLICIT-PATH matching. Defaults
      # to RENDER_METHOD; when the partials strategy is configured with
      # render_helpers, each helper name is added to the alternation so an
      # app-specific helper that renders a partial from a string path is treated
      # like render for explicit-path detection.
      #
      #   strategies:
      #     partials:
      #       render_helpers:
      #         - view_to_html_string
      #         - tabs_json
      #
      # Helper names are Regexp.quote'd so metacharacters match literally, and
      # the caller keeps the (?<!\w) left-anchor so tabs_json does not match
      # my_tabs_json. Returns RENDER_METHOD unchanged when none are configured,
      # so default behavior is byte-identical to today.
      #
      def render_method_pattern
        helpers = Keela.configuration.options_for(name)["render_helpers"]
        return RENDER_METHOD unless helpers.is_a?(Array) && helpers.any?

        quoted = helpers.map { |h| Regexp.quote(h.to_s) }
        /(?:render(?:_to_string|_to_body)?|#{quoted.join('|')})\s*\(?\s*/
      end
    end
  end
end
