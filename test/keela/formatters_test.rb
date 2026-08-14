# frozen_string_literal: true

require "test_helper"
require "json"

class FormattersTest < Minitest::Test
  FakeStrategy = Struct.new(:name)

  def setup
    @results = {
      "methods" => {
        "app/models/user.rb" => ["foo", "bar"],
        "app/models/post.rb" => ["baz"]
      },
      "scopes" => {}
    }
    @strategies = [
      FakeStrategy.new("methods"),
      FakeStrategy.new("scopes")
    ]
  end

  def test_structured_format_returns_true_for_json
    assert Keela::Formatters.structured_format?(:json)
  end

  def test_structured_format_returns_true_for_toon
    assert Keela::Formatters.structured_format?(:toon)
  end

  def test_structured_format_returns_false_for_text
    refute Keela::Formatters.structured_format?(:text)
  end

  def test_structured_format_returns_false_for_nil
    refute Keela::Formatters.structured_format?(nil)
  end

  def test_for_returns_json_formatter
    assert_equal Keela::Formatters::Json, Keela::Formatters.for(:json)
  end

  def test_for_returns_toon_formatter
    assert_equal Keela::Formatters::Toon, Keela::Formatters.for(:toon)
  end

  def test_for_returns_nil_for_unknown
    assert_nil Keela::Formatters.for(:unknown)
  end

  def test_json_formatter_output
    formatter = Keela::Formatters::Json.new(results: @results, strategies: @strategies)
    output = JSON.parse(formatter.format)

    assert_equal %w[methods scopes], output["strategies"]
    assert_equal 3, output["summary"]["total"]
    assert_equal({ "methods" => 3 }, output["summary"]["by_strategy"])
    assert_equal %w[foo bar], output["unused"]["methods"]["app/models/user.rb"]
  end

  def test_toon_formatter_output
    formatter = Keela::Formatters::Toon.new(results: @results, strategies: @strategies)
    output = formatter.format

    assert_includes output, "strategies[2]: methods,scopes"
    assert_includes output, "total: 3"
    assert_includes output, "methods: 3"
  end

  def test_json_formatter_excludes_empty_results
    formatter = Keela::Formatters::Json.new(results: @results, strategies: @strategies)
    output = JSON.parse(formatter.format)

    refute output["unused"].key?("scopes")
  end

  def test_toon_formatter_excludes_empty_results
    formatter = Keela::Formatters::Toon.new(results: @results, strategies: @strategies)
    output = formatter.format

    # scopes should not appear in unused section
    refute_match(/unused:.*scopes:/m, output)
  end
end
