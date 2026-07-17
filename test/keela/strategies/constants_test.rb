# frozen_string_literal: true

require "test_helper"

class ConstantsStrategyTest < Minitest::Test
  def setup
    @strategy = Keela::Strategies::Constants.new
  end

  def test_name
    assert_equal "constants", @strategy.name
  end

  def test_skips_comments
    assert @strategy.skip_comments?
  end

  # definition_file_pattern tests

  def test_matches_app_models_files
    assert_match @strategy.definition_file_pattern, "app/models/user.rb"
  end

  def test_matches_app_services_files
    assert_match @strategy.definition_file_pattern, "app/services/create_user.rb"
  end

  def test_matches_app_workers_files
    assert_match @strategy.definition_file_pattern, "app/workers/cleanup_job.rb"
  end

  def test_matches_lib_files
    assert_match @strategy.definition_file_pattern, "lib/gitlab/utils.rb"
  end

  def test_matches_ee_app_models_files
    assert_match @strategy.definition_file_pattern, "ee/app/models/license.rb"
  end

  def test_matches_ee_lib_files
    assert_match @strategy.definition_file_pattern, "ee/lib/ee/gitlab/auth.rb"
  end

  def test_does_not_match_spec_files
    refute_match @strategy.definition_file_pattern, "spec/models/user_spec.rb"
  end

  def test_does_not_match_test_files
    refute_match @strategy.definition_file_pattern, "test/models/user_test.rb"
  end

  # extract_definition tests

  def test_extracts_simple_constant
    assert_equal "MAX_SIZE", @strategy.extract_definition("MAX_SIZE = 100")
  end

  def test_extracts_constant_with_freeze
    assert_equal "ALLOWED_TYPES", @strategy.extract_definition("ALLOWED_TYPES = %w[foo bar].freeze")
  end

  def test_extracts_constant_with_hash
    assert_equal "OPTIONS", @strategy.extract_definition("OPTIONS = { foo: 1, bar: 2 }.freeze")
  end

  def test_extracts_constant_with_array
    assert_equal "ITEMS", @strategy.extract_definition("ITEMS = [1, 2, 3].freeze")
  end

  def test_extracts_constant_with_string
    assert_equal "DEFAULT_NAME", @strategy.extract_definition('DEFAULT_NAME = "unknown"')
  end

  def test_extracts_constant_with_leading_whitespace
    assert_equal "INDENTED", @strategy.extract_definition("    INDENTED = true")
  end

  def test_extracts_constant_with_heredoc
    assert_equal "TEMPLATE", @strategy.extract_definition("TEMPLATE = <<~SQL")
  end

  def test_does_not_match_lowercase_names
    assert_nil @strategy.extract_definition("my_var = 100")
  end

  def test_does_not_match_class_definitions
    assert_nil @strategy.extract_definition("class MyClass")
  end

  def test_does_not_match_module_definitions
    assert_nil @strategy.extract_definition("module MyModule")
  end

  def test_does_not_match_method_definitions
    assert_nil @strategy.extract_definition("def my_method")
  end

  def test_does_not_match_comparisons
    assert_nil @strategy.extract_definition("if MAX_SIZE == 100")
  end

  def test_does_not_match_usage_in_conditionals
    assert_nil @strategy.extract_definition("return if ENABLED")
  end

  def test_does_not_match_namespaced_constant_access
    # This is usage, not definition
    assert_nil @strategy.extract_definition("Foo::BAR")
  end

  def test_extracts_constant_after_class_or_module_reopening
    # Inside a class/module body
    assert_equal "LIMIT", @strategy.extract_definition("  LIMIT = 50")
  end

  # usage_regex tests

  def test_usage_regex_matches_direct_reference
    regex = @strategy.usage_regex("MAX_SIZE")
    assert_match regex, "if size > MAX_SIZE"
  end

  def test_usage_regex_matches_namespaced_reference
    regex = @strategy.usage_regex("MAX_SIZE")
    assert_match regex, "MyClass::MAX_SIZE"
  end

  def test_usage_regex_matches_in_array
    regex = @strategy.usage_regex("TYPES")
    assert_match regex, "[TYPES, OTHER]"
  end

  def test_usage_regex_matches_in_hash_value
    regex = @strategy.usage_regex("DEFAULT")
    assert_match regex, "{ key: DEFAULT }"
  end

  def test_usage_regex_matches_as_argument
    regex = @strategy.usage_regex("LIMIT")
    assert_match regex, "paginate(LIMIT)"
  end

  def test_usage_regex_does_not_match_definition
    regex = @strategy.usage_regex("MAX_SIZE")
    refute_match regex, "MAX_SIZE = 100"
  end

  def test_usage_regex_does_not_match_partial_name
    regex = @strategy.usage_regex("MAX")
    refute_match regex, "MAXIMUM_SIZE"
  end

  def test_usage_regex_does_not_match_in_string
    # This is tricky - we can't perfectly avoid string matches,
    # but we should at least not match the definition pattern
    regex = @strategy.usage_regex("FOO")
    refute_match regex, "FOO = 'bar'"
  end
end
