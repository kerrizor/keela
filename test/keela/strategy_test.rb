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

  def test_used_delegates_to_usage_regex_by_default
    strategy = Class.new(Keela::Strategy) do
      def name = "fake"
      def usage_regex(definition_name) = /#{Regexp.quote(definition_name)}/
    end.new

    assert strategy.used?("name", Keela::Source.new("user.name"))
    refute strategy.used?("name", Keela::Source.new("nothing here"))
  end

  def test_used_matches_against_the_raw_source_not_a_derived_view
    strategy = Class.new(Keela::Strategy) do
      def name = "fake"
      def usage_regex(definition_name) = /#{Regexp.quote(definition_name)}/
    end.new

    # Case-sensitive by default: a strategy that has not opted into folding must
    # not accidentally get the folded source.
    refute strategy.used?("name", Keela::Source.new("user.NAME"))
  end

  def test_used_raises_not_implemented_without_a_usage_regex
    assert_raises(NotImplementedError) { @strategy.used?("name", Keela::Source.new("")) }
  end

  def test_prepare_defaults_to_doing_nothing
    source = Keela::Source.new("user.name")

    assert_nil @strategy.prepare(source)
    refute source.instance_variable_defined?(:@folded)
  end
end
