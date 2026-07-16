# frozen_string_literal: true

require "test_helper"

class StrategyTest < Minitest::Test
  def setup
    @strategy = Keela::Strategy.new
  end

  def test_name_raises_not_implemented
    assert_raises(NotImplementedError) { @strategy.name }
  end

  def test_definition_file_pattern_raises_not_implemented
    assert_raises(NotImplementedError) { @strategy.definition_file_pattern }
  end

  def test_extract_definition_raises_not_implemented
    assert_raises(NotImplementedError) { @strategy.extract_definition("line") }
  end

  def test_usage_regex_raises_not_implemented
    assert_raises(NotImplementedError) { @strategy.usage_regex("name") }
  end

  def test_skip_comments_defaults_to_false
    refute @strategy.skip_comments?
  end
end
