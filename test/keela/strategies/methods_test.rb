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

class MethodsSelfMethodTest < Minitest::Test
  def setup
    @strategy = Keela::Strategies::Methods.new
  end

  def test_extract_definition_captures_self_methods
    assert_equal "self.class_method", @strategy.extract_definition("def self.class_method")
    assert_equal "self.class_method", @strategy.extract_definition("  def self.class_method(arg)")
  end

  def test_usage_regex_excludes_self_method_definitions
    regex = @strategy.usage_regex("self.class_method")

    # Should NOT match definitions
    refute regex.match?("def self.class_method")
    refute regex.match?("  def self.class_method(arg)")

    # Should match actual usage
    assert regex.match?("User.class_method()")
    assert regex.match?("self.class_method()")
    assert regex.match?("result = class_method()")
  end

  def test_usage_regex_excludes_regular_method_definitions
    regex = @strategy.usage_regex("instance_method")

    # Should NOT match definitions
    refute regex.match?("def instance_method")
    refute regex.match?("  def instance_method(arg)")

    # Should match actual usage
    assert regex.match?("obj.instance_method()")
    assert regex.match?("instance_method()")
  end
end

class MethodsSymbolUsageTest < Minitest::Test
  def setup
    @strategy = Keela::Strategies::Methods.new
  end

  # Rails model callbacks
  def test_usage_regex_matches_before_save_callback
    regex = @strategy.usage_regex("ensure_token")
    assert_match regex, "before_save :ensure_token"
  end

  def test_usage_regex_matches_after_create_callback
    regex = @strategy.usage_regex("send_welcome_email")
    assert_match regex, "after_create :send_welcome_email"
  end

  def test_usage_regex_matches_before_validation_callback
    regex = @strategy.usage_regex("normalize_email")
    assert_match regex, "before_validation :normalize_email, if: :email_changed?"
  end

  # Rails controller callbacks
  def test_usage_regex_matches_before_action_callback
    regex = @strategy.usage_regex("authenticate_user!")
    assert_match regex, "before_action :authenticate_user!"
  end

  def test_usage_regex_matches_after_action_callback
    regex = @strategy.usage_regex("log_request")
    assert_match regex, "after_action :log_request, only: [:create, :update]"
  end

  # Validation callbacks
  def test_usage_regex_matches_validate_callback
    regex = @strategy.usage_regex("check_valid_state")
    assert_match regex, "validate :check_valid_state"
  end

  # Dynamic invocation with literal symbols
  def test_usage_regex_matches_send_with_literal_symbol
    regex = @strategy.usage_regex("process_data")
    assert_match regex, "send(:process_data)"
  end

  def test_usage_regex_matches_public_send_with_literal_symbol
    regex = @strategy.usage_regex("handle_event")
    assert_match regex, "public_send(:handle_event, args)"
  end

  def test_usage_regex_matches___send___with_literal_symbol
    regex = @strategy.usage_regex("internal_method")
    assert_match regex, "__send__(:internal_method)"
  end

  # Other metaprogramming patterns
  def test_usage_regex_matches_respond_to_check
    regex = @strategy.usage_regex("optional_method")
    assert_match regex, "respond_to?(:optional_method)"
  end

  def test_usage_regex_matches_try_call
    regex = @strategy.usage_regex("maybe_nil")
    assert_match regex, "obj.try(:maybe_nil)"
  end

  def test_usage_regex_matches_method_reference
    regex = @strategy.usage_regex("to_be_called")
    assert_match regex, "method(:to_be_called).call"
  end

  # Symbol in arrays/hashes (common in Rails)
  def test_usage_regex_matches_symbol_in_array
    regex = @strategy.usage_regex("allowed_action")
    assert_match regex, "only: [:allowed_action, :other]"
  end

  def test_usage_regex_matches_symbol_as_hash_value
    regex = @strategy.usage_regex("handler_method")
    assert_match regex, "{ on_success: :handler_method }"
  end

  # Edge cases - should NOT match
  def test_usage_regex_does_not_match_partial_symbol
    regex = @strategy.usage_regex("foo")
    refute_match regex, ":foobar"
  end

  def test_usage_regex_does_not_match_symbol_within_larger_symbol
    regex = @strategy.usage_regex("save")
    refute_match regex, ":before_save"
  end
end
