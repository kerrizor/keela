# frozen_string_literal: true

require "test_helper"

class DelegationsStrategyTest < Minitest::Test
  def setup
    @strategy = Keela::Strategies::Delegations.new
  end

  def test_name
    assert_equal "delegations", @strategy.name
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

  def test_matches_ee_app_models_files
    assert_match @strategy.definition_file_pattern, "ee/app/models/license.rb"
  end

  def test_does_not_match_app_controllers_files
    refute_match @strategy.definition_file_pattern, "app/controllers/users_controller.rb"
  end

  def test_does_not_match_lib_files
    refute_match @strategy.definition_file_pattern, "lib/gitlab/utils.rb"
  end

  def test_does_not_match_spec_files
    refute_match @strategy.definition_file_pattern, "spec/models/user_spec.rb"
  end

  # extract_definition tests - single method

  def test_extracts_simple_delegation
    assert_equal "name", @strategy.extract_definition("delegate :name, to: :user")
  end

  def test_extracts_delegation_with_allow_nil
    assert_equal "email", @strategy.extract_definition("delegate :email, to: :user, allow_nil: true")
  end

  def test_extracts_delegation_with_prefix
    assert_equal "user_name", @strategy.extract_definition("delegate :name, to: :user, prefix: true")
  end

  def test_extracts_delegation_with_custom_prefix
    assert_equal "owner_name", @strategy.extract_definition("delegate :name, to: :user, prefix: :owner")
  end

  def test_extracts_delegation_with_leading_whitespace
    assert_equal "title", @strategy.extract_definition("    delegate :title, to: :project")
  end

  # extract_definition tests - multiple methods
  # Note: When multiple methods are delegated on one line, we return the first one.
  # This is a limitation - ideally we'd return all, but the scanner expects single values.

  def test_extracts_multiple_delegations_returns_first
    # When multiple methods are delegated on one line, we return the first
    result = @strategy.extract_definition("delegate :name, :email, to: :user")
    assert_equal "name", result
  end

  def test_extracts_multiple_delegations_with_prefix_returns_first
    result = @strategy.extract_definition("delegate :name, :email, to: :user, prefix: true")
    assert_equal "user_name", result
  end

  def test_extracts_multiple_delegations_with_custom_prefix_returns_first
    result = @strategy.extract_definition("delegate :name, :email, to: :user, prefix: :owner")
    assert_equal "owner_name", result
  end

  # extract_definition tests - edge cases

  def test_does_not_match_non_delegate_lines
    assert_nil @strategy.extract_definition("def delegate_work")
  end

  def test_does_not_match_method_definitions
    assert_nil @strategy.extract_definition("def name")
  end

  def test_does_not_match_comments
    assert_nil @strategy.extract_definition("# delegate :name, to: :user")
  end

  def test_handles_delegation_to_instance_variable
    assert_equal "count", @strategy.extract_definition("delegate :count, to: :@items")
  end

  def test_handles_delegation_to_class
    assert_equal "logger", @strategy.extract_definition("delegate :logger, to: :class")
  end

  def test_extracts_predicate_method_delegation
    assert_equal "enabled?", @strategy.extract_definition("delegate :enabled?, to: :settings")
  end

  def test_extracts_bang_method_delegation
    assert_equal "save!", @strategy.extract_definition("delegate :save!, to: :record")
  end

  # usage_regex tests

  def test_usage_regex_matches_method_call
    regex = @strategy.usage_regex("name")
    assert_match regex, "user.name"
  end

  def test_usage_regex_matches_method_call_with_parens
    regex = @strategy.usage_regex("name")
    assert_match regex, "name()"
  end

  def test_usage_regex_matches_method_in_interpolation
    regex = @strategy.usage_regex("name")
    assert_match regex, '#{name}'
  end

  def test_usage_regex_does_not_match_delegate_definition
    regex = @strategy.usage_regex("name")
    refute_match regex, "delegate :name, to: :user"
  end

  def test_usage_regex_does_not_match_symbol
    regex = @strategy.usage_regex("name")
    refute_match regex, ":name"
  end

  def test_usage_regex_does_not_match_partial_word
    regex = @strategy.usage_regex("name")
    refute_match regex, "username"
  end

  def test_usage_regex_matches_prefixed_delegation_usage
    regex = @strategy.usage_regex("user_name")
    assert_match regex, "object.user_name"
  end
end
