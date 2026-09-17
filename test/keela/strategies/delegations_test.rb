# frozen_string_literal: true

require "test_helper"

class DelegationsStrategyTest < Minitest::Test
  include UsageEquivalence

  ESZETT = "\u00DF"           # folds to "ss", so folding shifts positions
  KELVIN_SIGN = "\u212A"      # folds to ASCII "k"
  E_ACUTE_CAPITAL = "\u00C9"  # folds to a non-ASCII character

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

  def test_extracts_multiple_delegations
    result = @strategy.extract_definition("delegate :name, :email, to: :user")
    assert_equal %w[name email], result
  end

  def test_extracts_multiple_delegations_with_prefix
    result = @strategy.extract_definition("delegate :name, :email, to: :user, prefix: true")
    assert_equal %w[user_name user_email], result
  end

  def test_extracts_multiple_delegations_with_custom_prefix
    result = @strategy.extract_definition("delegate :name, :email, to: :user, prefix: :owner")
    assert_equal %w[owner_name owner_email], result
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

  # prepare tests

  def test_prepare_warms_the_fold_before_workers_fork
    source = Keela::Source.new("user.name")

    refute source.instance_variable_defined?(:@folded)
    @strategy.prepare(source)

    assert source.instance_variable_defined?(:@folded)
    assert source.instance_variable_defined?(:@fold_preserves_matching)
  end

  # used? tests - the ordinary cases

  def test_used_for_method_call
    assert_used "name", "puts user.name"
  end

  def test_used_without_receiver
    assert_used "name", "puts name"
  end

  def test_used_for_predicate_method
    assert_used "valid?", "return unless record.valid?\n"
  end

  def test_used_for_bang_method
    assert_used "save!", "record.save!\n"
  end

  def test_used_for_prefixed_name
    assert_used "user_name", "puts record.user_name\n"
  end

  def test_used_at_the_very_start_of_the_source
    assert_used "name", "name"
  end

  # used? tests - what must not count as usage

  def test_not_used_for_the_delegate_declaration_alone
    refute_used "name", "delegate :name, to: :user\n"
  end

  def test_not_used_for_symbol_reference_alone
    refute_used "name", "validates :name\n"
  end

  def test_not_used_for_partial_word
    refute_used "name", "username\n"
  end

  def test_not_used_when_preceded_by_an_underscore
    refute_used "name", "full_name\n"
  end

  def test_not_used_when_followed_by_a_word_character
    refute_used "name", "names\n"
  end

  def test_not_used_when_absent
    refute_used "name", "class User\nend\n"
  end

  def test_not_used_for_empty_source
    refute_used "name", ""
  end

  # used? tests - case insensitivity, which is why this strategy folds

  def test_used_for_capitalised_occurrence
    assert_used "name", "record.Name\n"
  end

  def test_used_for_upper_case_occurrence
    assert_used "name", "record.NAME\n"
  end

  def test_used_for_mixed_case_occurrence
    assert_used "user_name", "record.User_Name\n"
  end

  def test_not_used_for_capitalised_partial_word
    refute_used "name", "UserName\n"
  end

  def test_used_when_the_definition_name_itself_has_capitals
    assert_used "Name", "record.name\n"
  end

  def test_not_used_for_upper_case_delegate_declaration_alone
    refute_used "name", "DELEGATE :name, to: :user\n"
  end

  # used? tests - the fast path and the fallback must agree

  def test_takes_the_fast_path_on_ascii_source
    source = Keela::Source.new("record.Name\n")

    assert_predicate source, :fold_preserves_matching?
    assert @strategy.used?("name", source)
  end

  def test_falls_back_when_folding_shifts_positions
    # "ss" from the eszett makes the folded view a different length, so #used?
    # must use the //i pattern instead and still agree with it.
    source = Keela::Source.new("STRA#{ESZETT}E\nrecord.name\n")

    refute_predicate source, :fold_preserves_matching?
    assert_used "name", source.text
  end

  def test_falls_back_when_non_ascii_folds_into_ascii
    source = Keela::Source.new("#{KELVIN_SIGN}elvin\nrecord.name\n")

    refute_predicate source, :fold_preserves_matching?
    assert_used "name", source.text
  end

  def test_fallback_still_reports_unused_correctly
    refute_used "name", "STRA#{ESZETT}E\nclass User\nend\n"
  end

  def test_eszett_source_agrees_for_the_name_folding_would_find
    # /strasse/i matches the eszett spelling, so "strasse" is used. The folded
    # view spells it "strasse" too, but at shifted positions, which is exactly
    # the case the guard exists for.
    assert_used "strasse", "value = STRA#{ESZETT}E\n"
  end

  def test_non_ascii_source_that_folds_cleanly_keeps_the_fast_path
    source = Keela::Source.new("# #{E_ACUTE_CAPITAL}quipe\nrecord.name\n")

    assert_predicate source, :fold_preserves_matching?
    assert_used "name", source.text
  end

  def test_non_ascii_name_falls_back
    name = "nom#{E_ACUTE_CAPITAL}"

    refute_predicate name, :ascii_only?
    assert_equivalent name, "record.nom#{E_ACUTE_CAPITAL}\n"
  end

  # used? tests - equivalence over a broad table

  def test_used_agrees_with_usage_regex_across_many_shapes
    names = ["name", "valid?", "save!", "user_name", "id", "a", "Name", "name2"]
    sources = [
      "", "name", "Name", "NAME", "user.name", ":name", "delegate :name, to: :user",
      "delegate name", "DELEGATE name", "username", "UserName", "full_name", "names",
      "record.valid?", "valid?", ":valid?", "record.save!", "a", "a.b", "id",
      "name2", "Name2", "# name\n", "\"name\"", "send(:name)", "obj&.name",
      "name ||= 1", "namespace", "renamed", "STRA#{ESZETT}E", "#{KELVIN_SIGN}elvin",
      "#{E_ACUTE_CAPITAL}quipe name", "delegate :name, to: :user\nrecord.name\n"
    ]

    names.each do |name|
      sources.each { |source| assert_equivalent name, source }
    end
  end

  def test_used_agrees_with_usage_regex_on_generated_input
    random = Random.new(4321)
    alphabet = ["name", "Name", "NAME", "username", ":name", "delegate :name", "record.",
      ".", "_", "\n", "foo", ESZETT, KELVIN_SIGN, E_ACUTE_CAPITAL]

    300.times do
      name = %w[name valid? user_name].sample(random: random)
      source = Array.new(random.rand(1..12)) { alphabet.sample(random: random) }.join

      assert_equivalent name, source
    end
  end
end
