# frozen_string_literal: true

require "test_helper"

class ScopesStrategyTest < Minitest::Test
  def setup
    @strategy = Keela::Strategies::Scopes.new
  end

  def test_name
    assert_equal "scopes", @strategy.name
  end

  def test_skips_comments
    assert @strategy.skip_comments?
  end

  # definition_file_pattern tests

  def test_matches_app_models_files
    assert_match @strategy.definition_file_pattern, "app/models/user.rb"
  end

  def test_matches_app_models_concerns_files
    assert_match @strategy.definition_file_pattern, "app/models/concerns/issuable.rb"
  end

  def test_matches_ee_app_models_files
    assert_match @strategy.definition_file_pattern, "ee/app/models/license.rb"
  end

  def test_does_not_match_app_helpers_files
    refute_match @strategy.definition_file_pattern, "app/helpers/application_helper.rb"
  end

  def test_does_not_match_lib_files
    refute_match @strategy.definition_file_pattern, "lib/gitlab/database.rb"
  end

  # extract_definition tests

  def test_extracts_single_line_scope_definitions
    assert_equal "active", @strategy.extract_definition("scope :active, -> { where(active: true) }")
  end

  def test_extracts_scope_definitions_with_arguments
    assert_equal "by_status", @strategy.extract_definition("scope :by_status, ->(status) { where(status: status) }")
  end

  def test_extracts_multi_line_scope_definitions
    assert_equal "complex", @strategy.extract_definition("scope :complex, ->(arg) do")
  end

  def test_extracts_scope_names_with_underscores
    assert_equal "with_long_name", @strategy.extract_definition("scope :with_long_name, -> { }")
  end

  def test_extracts_scope_names_with_numbers
    assert_equal "version_2", @strategy.extract_definition("scope :version_2, -> { }")
  end

  def test_does_not_match_default_scope
    assert_nil @strategy.extract_definition("default_scope { where(deleted: false) }")
  end

  def test_does_not_match_method_definitions
    assert_nil @strategy.extract_definition("def active")
  end

  # usage_regex tests

  def test_usage_regex_matches_scope_calls
    regex = @strategy.usage_regex("active")
    assert_match regex, ".active."
    assert_match regex, "User.active "
    assert_match regex, ".active("
  end

  def test_usage_regex_does_not_match_scope_definitions
    regex = @strategy.usage_regex("active")
    refute_match regex, "scope :active"
  end

  def test_usage_regex_does_not_match_method_definitions
    regex = @strategy.usage_regex("active")
    refute_match regex, "def active"
  end
end
