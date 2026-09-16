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
    # USAGE DETECTION IS ARGUMENT-MATCHING (method-agnostic). This is the key
    # difference from the method-anchored partials strategy (PR #82), which only
    # counted a partial as used when it saw render / render_to_string /
    # render_to_body before the argument. Empirically, in the files this strategy
    # scans (app/views, ee/app/views, app/controllers, ee/app/controllers), a
    # bare partial:/layout: string or a positional partial-path string is
    # essentially ALWAYS a render, so matching the ARGUMENT rather than the
    # method costs ~0 false negatives while being simpler and catching custom
    # helpers (view_to_html_string, tabs_json) and multi-line renders (args
    # before a detached partial:) for free.
    #
    # Usage is detected three ways:
    #   1. Explicit-path key forms via #usage_regex: partial: "users/form" /
    #      layout: "users/form", regardless of the preceding method. layout:
    #      renders a partial as a layout, so it counts as a use.
    #   2. Positional-underscore paths via #additional_used_names: any string
    #      whose basename starts with _ names a partial file directly, e.g.
    #      view_to_html_string("shared/notes/_note") uses shared/notes/note.
    #   3. Relative (bareword) key forms via #additional_used_names: partial:
    #      "form" / layout: "form" (no slash) is resolved against the CALLING
    #      file's directory. In a view, the directory is the view's own dir; in a
    #      controller, it is derived from the controller name
    #      (users_controller.rb -> users).
    #
    # A bare positional string with NO partial:/layout: key AND no leading
    # underscore (render "users/form", some_helper("users/form")) is
    # intentionally NOT matched: without the method anchor, an arbitrary string
    # literal is too ambiguous to treat as a partial path. The key or the
    # explicit underscore is what disambiguates.
    #
    # Known limitations (not implemented, by design):
    #   - Collection/object render (render @users -> users/_user) is NOT
    #     resolved. A singularize heuristic could silently hide dead code on a
    #     wrong guess, so these partials may be reported as unused; suppress via
    #     the baseline.
    #   - Dynamic render with a variable (render partial_name) is statically
    #     unsolvable, so it is not resolved (same posture as send for methods).
    #   - A partial:/layout: key nested in a locals: hash (locals: { layout:
    #     'errors' }) would be matched, but such values are not partial paths, so
    #     at worst they harmlessly mark a non-existent partial used. Rare enough
    #     not to warrant special-casing.
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

      # A bareword key-form render: partial: "form" / layout: "form" with no
      # slash in the value. The method is deliberately ignored. Only barewords
      # (no slash) are captured here; slash paths are matched directly by
      # #usage_regex.
      #
      BAREWORD_KEY_REGEX = /(?:partial|layout):\s*["']([^"'\/]+)["']/

      # A positional string whose basename starts with _ names a partial file
      # directly, with the file's leading _ still present:
      # view_to_html_string("shared/notes/_note") uses shared/notes/note, and
      # render "users/_form" uses users/form. #usage_regex matches the logical
      # name (underscore already stripped), so this pass re-adds the underscore
      # variant to the used set. Only the leading _ of the BASENAME is stripped;
      # intermediate path segments are kept verbatim.
      #
      POSITIONAL_UNDERSCORE_REGEX = %r{["']([^"']*/_[^"'/]+)["']}.freeze

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

      # Full argument-matching, method-agnostic. A partial NAME (which always
      # contains a slash for a real partial under a directory) is used when it
      # appears as:
      #   1. a partial:/layout: key value: partial: "users/form" (layout:
      #      renders a partial as a layout, so it counts too); or
      #   2. a bare positional slash-path string: render "users/form",
      #      some_helper("users/form"), or just "users/form".
      #
      # The render method is deliberately NOT required: empirically, quoted
      # "a/b" strings in the scanned view/controller dirs are essentially always
      # renders, so matching the argument catches custom helpers and multi-line
      # renders for free at ~0 false-negative cost. The value is anchored on both
      # sides by the quotes, so "users/form" cannot match "users/form_wrapper".
      #
      # Slash-less names (root-level partials like "foo") do NOT get the bare
      # positional branch: a bare "foo" string is too ambiguous to treat as a
      # partial reference. They match only via the partial:/layout: key form; a
      # relative render "foo" is resolved against the caller directory in
      # #additional_used_names. Names WITH a slash get both branches.
      #
      def usage_regex(name)
        quoted = Regexp.quote(name)

        if name.include?("/")
          /(?:(?:partial|layout):\s*)?["']#{quoted}["']/
        else
          /(?:partial|layout):\s*["']#{quoted}["']/
        end
      end

      def skip_comments?
        true
      end

      # Resolve positional-underscore paths and bareword key-form renders that
      # #usage_regex cannot express as a per-name pattern.
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

          content.scan(BAREWORD_KEY_REGEX).each do |(bareword)|
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
