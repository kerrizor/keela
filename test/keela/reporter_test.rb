# frozen_string_literal: true

require "test_helper"

class ReporterTest < Minitest::Test
  def setup
    @reporter = Keela::Reporter.new("methods")
  end

  def test_print_stale_exclusions_renders_message_and_entries
    stale = { "app/models/user.rb" => ["vanished_method"] }

    output = capture_io do
      @reporter.print_stale_exclusions(stale, "excluded.yml")
    end

    combined = output[0]
    assert_match(/stale methods exclusion/, combined)
    assert_match(/excluded\.yml/, combined)
    assert_match(/vanished_method/, combined)
  end

  def test_print_stale_exclusions_reports_count
    stale = {
      "app/models/user.rb" => ["a", "b"],
      "app/models/post.rb" => ["c"]
    }

    output = capture_io do
      @reporter.print_stale_exclusions(stale, "excluded.yml")
    end

    assert_match(/3 stale/, output[0])
  end
end
