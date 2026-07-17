# frozen_string_literal: true

require "test_helper"

class AttributesStrategyTest < Minitest::Test
  def setup
    @strategy = Keela::Strategies::Attributes.new
  end

  def test_name
    assert_equal "attributes", @strategy.name
  end

  def test_skips_comments
    assert @strategy.skip_comments?
  end

  # definition_file_pattern tests

  def test_matches_app_models_files
    assert_match @strategy.definition_file_pattern, "app/models/user.rb"
  end

  def test_matches_app_models_concerns_files
    assert_match @strategy.definition_file_pattern, "app/models/concerns/trackable.rb"
  end

  def test_matches_lib_files
    assert_match @strategy.definition_file_pattern, "lib/gitlab/utils.rb"
  end

  def test_matches_ee_app_models_files
    assert_match @strategy.definition_file_pattern, "ee/app/models/license.rb"
  end

  def test_does_not_match_spec_files
    refute_match @strategy.definition_file_pattern, "spec/models/user_spec.rb"
  end

  def test_does_not_match_test_files
    refute_match @strategy.definition_file_pattern, "test/models/user_test.rb"
  end

  # extract_definition tests - attr_accessor

  def test_extracts_attr_accessor
    assert_equal "name", @strategy.extract_definition("attr_accessor :name")
  end

  def test_extracts_attr_accessor_with_leading_whitespace
    assert_equal "name", @strategy.extract_definition("  attr_accessor :name")
  end

  def test_extracts_first_attr_accessor_from_multiple
    # When multiple attrs on one line, return first
    assert_equal "name", @strategy.extract_definition("attr_accessor :name, :email")
  end

  # extract_definition tests - attr_reader

  def test_extracts_attr_reader
    assert_equal "count", @strategy.extract_definition("attr_reader :count")
  end

  def test_extracts_attr_reader_with_leading_whitespace
    assert_equal "items", @strategy.extract_definition("    attr_reader :items")
  end

  # extract_definition tests - attr_writer

  def test_extracts_attr_writer
    assert_equal "value", @strategy.extract_definition("attr_writer :value")
  end

  # extract_definition tests - edge cases

  def test_does_not_match_attr_encrypted
    # attr_encrypted is a different DSL, not a simple attribute
    assert_nil @strategy.extract_definition("attr_encrypted :secret")
  end

  def test_does_not_match_attr_spammable
    assert_nil @strategy.extract_definition("attr_spammable :note")
  end

  def test_does_not_match_attr_mentionable
    assert_nil @strategy.extract_definition("attr_mentionable :note")
  end

  def test_does_not_match_method_definitions
    assert_nil @strategy.extract_definition("def attr_accessor")
  end

  def test_does_not_match_comments
    assert_nil @strategy.extract_definition("# attr_accessor :name")
  end

  def test_does_not_match_string_content
    assert_nil @strategy.extract_definition('"attr_accessor :name"')
  end

  # usage_regex tests - attr_accessor (both getter and setter)

  def test_usage_regex_matches_getter_call
    regex = @strategy.usage_regex("name")
    assert_match regex, "user.name"
  end

  def test_usage_regex_matches_getter_without_receiver
    regex = @strategy.usage_regex("name")
    assert_match regex, "puts name"
  end

  def test_usage_regex_matches_setter_call
    regex = @strategy.usage_regex("name")
    assert_match regex, "self.name = value"
  end

  def test_usage_regex_matches_instance_variable_read
    regex = @strategy.usage_regex("name")
    assert_match regex, "@name"
  end

  def test_usage_regex_matches_instance_variable_write
    regex = @strategy.usage_regex("name")
    assert_match regex, "@name = value"
  end

  def test_usage_regex_does_not_match_attr_definition
    regex = @strategy.usage_regex("name")
    refute_match regex, "attr_accessor :name"
  end

  def test_usage_regex_does_not_match_symbol
    regex = @strategy.usage_regex("name")
    refute_match regex, ":name"
  end

  def test_usage_regex_does_not_match_partial_word
    regex = @strategy.usage_regex("name")
    refute_match regex, "username"
  end

  def test_usage_regex_does_not_match_partial_instance_variable
    regex = @strategy.usage_regex("name")
    refute_match regex, "@username"
  end
end
