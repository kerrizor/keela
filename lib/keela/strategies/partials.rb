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
      BAREWORD_RENDER_REGEX = /(?<!\w)#{RENDER_METHOD}(?:(?:partial|layout):\s*)?["']([^"'\/]+)["']/

      # A positional string whose basename starts with _ names a partial file
      # directly: render_to_string("shared/notes/_note") uses shared/notes/note.
      # There is no partial:/layout: keyword here, so it is handled separately
      # from #usage_regex and the bareword path. Only the leading _ of the
      # BASENAME is stripped; intermediate path segments are kept verbatim.
      #
      POSITIONAL_UNDERSCORE_REGEX = /(?<!\w)#{RENDER_METHOD}["']([^"']*\/_[^"'\/]+)["']/

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
        /(?<!\w)#{RENDER_METHOD}(?:(?:partial|layout):\s*)?["']#{Regexp.quote(name)}["']/
      end

      def skip_comments?
        true
      end

      # Resolve bareword renders against the calling file's directory so that a
      # short render marks the fully-qualified partial used.
      #
      def additional_used_names(source_files)
        used = Set.new

        source_files.each do |filepath, lines|
          content = lines.join("\n")

          # Positional-underscore paths are absolute logical names, so they are
          # resolved regardless of the caller's directory. "shared/notes/_note"
          # -> "shared/notes/note" (strip the leading _ of the basename only).
          #
          content.scan(POSITIONAL_UNDERSCORE_REGEX).each do |(path)|
            used << path.sub(%r{/_([^/]+)$}, '/\1')
          end

          dir = caller_directory(filepath)
          next unless dir

          content.scan(BAREWORD_RENDER_REGEX).each do |(bareword)|
            used << "#{dir}/#{bareword}"
          end
        end

        used
      end

      private

      # The directory a bareword render resolves against: the view's own dir, or
      # the controller-derived dir. Returns nil for files that render nothing
      # resolvable this way.
      #
      def caller_directory(filepath)
        return Regexp.last_match(1) if filepath =~ VIEW_DIR_REGEX
        return Regexp.last_match(1) if filepath =~ CONTROLLER_REGEX

        nil
      end
    end
  end
end
