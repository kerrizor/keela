# frozen_string_literal: true

require "test_helper"

class MethodsStrategyTest < Minitest::Test
  def setup
    @strategy = Keela::Strategies::Methods.new
  end

  def test_name
    assert_equal "methods", @strategy.name
  end

  def test_does_not_skip_comments
    refute @strategy.skip_comments?
  end

  # definition_file_pattern tests

  def test_matches_app_helpers_files
    assert_match @strategy.definition_file_pattern, "app/helpers/application_helper.rb"
  end

  def test_matches_app_models_files
    assert_match @strategy.definition_file_pattern, "app/models/user.rb"
  end

  def test_matches_ee_app_helpers_files
    assert_match @strategy.definition_file_pattern, "ee/app/helpers/ee_helper.rb"
  end

  def test_matches_ee_app_models_files
    assert_match @strategy.definition_file_pattern, "ee/app/models/license.rb"
  end

  def test_does_not_match_app_controllers_files
    refute_match @strategy.definition_file_pattern, "app/controllers/application_controller.rb"
  end

  def test_does_not_match_lib_files
    refute_match @strategy.definition_file_pattern, "lib/gitlab/utils.rb"
  end

  # extract_definition tests

  def test_extracts_simple_method_definitions
    assert_equal "foo", @strategy.extract_definition("def foo")
  end

  def test_extracts_method_definitions_with_arguments
    assert_equal "bar", @strategy.extract_definition("def bar(arg)")
  end

  def test_extracts_predicate_methods
    assert_equal "valid?", @strategy.extract_definition("def valid?")
  end

  def test_extracts_bang_methods
    assert_equal "save!", @strategy.extract_definition("def save!")
  end

  def test_extracts_class_methods
    assert_equal "self.create", @strategy.extract_definition("def self.create")
  end

  def test_extracts_setter_methods
    assert_equal "name=", @strategy.extract_definition("def name=(value)")
  end

  def test_does_not_match_scope_definitions
    assert_nil @strategy.extract_definition("scope :active, -> { }")
  end

  def test_does_not_match_non_method_lines
    assert_nil @strategy.extract_definition('puts "hello"')
  end

  # usage_regex tests

  def test_usage_regex_matches_method_calls
    regex = @strategy.usage_regex("foo")
    assert_match regex, "obj.foo "
    assert_match regex, "foo(arg)"
  end

  def test_usage_regex_does_not_match_method_definitions
    regex = @strategy.usage_regex("foo")
    refute_match regex, "def foo"
  end

  def test_usage_regex_handles_setter_methods
    regex = @strategy.usage_regex("name=")
    assert_match regex, "obj.name = value"
    assert_match regex, "self.name=value"
  end

  def test_usage_regex_handles_self_prefix_in_definition
    regex = @strategy.usage_regex("self.create")
    assert_match regex, "Model.create("
  end
end
