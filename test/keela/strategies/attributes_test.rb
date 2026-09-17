# frozen_string_literal: true

require "test_helper"

class AttributesStrategyTest < Minitest::Test
  include UsageEquivalence

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

  # usage_regexes tests - the alternation split

  def test_usage_regexes_returns_a_bare_pattern_and_an_ivar_pattern
    regexes = @strategy.usage_regexes("name")

    assert_equal 2, regexes.size

    bare, ivar = regexes

    assert_match bare, "user.name"
    assert_match ivar, "@name"
    refute_match ivar, "user.name"
  end

  def test_the_two_patterns_are_allowed_to_overlap
    # "@" is not in [a-z_], so the bare pattern matches "@name" too. The
    # original alternation behaved the same way; #used? only asks whether some
    # pattern matched, so the overlap changes nothing.
    bare, ivar = @strategy.usage_regexes("name")

    assert_match bare, "@name"
    assert_match ivar, "@name"
  end

  def test_the_ivar_pattern_is_needed_for_names_the_bare_pattern_rejects
    # A trailing word character stops the bare pattern but "@name" still reads
    # the attribute, so the second pattern has to exist.
    bare, ivar = @strategy.usage_regexes("name")
    source = "@name2 = 1\n@name = 2\n"

    assert_match ivar, source
    assert_match bare, source
  end

  def test_usage_regex_is_the_union_of_usage_regexes
    # usage_regex stays the documented single-pattern API; #used? is what got
    # faster. Both must keep answering alike.
    %w[name count value].each do |attribute|
      ["user.name", "@name", ":name", "username", "@count", "value = 1", "nothing"].each do |source|
        union = @strategy.usage_regex(attribute).match?(source)
        split = @strategy.usage_regexes(attribute).any? { |r| r.match?(source) }

        assert_equal union, split, "#{attribute.inspect} in #{source.inspect}"
      end
    end
  end

  def test_usage_regexes_quotes_the_name
    regexes = @strategy.usage_regexes("a.b")

    refute_match regexes[0], "axb"
    assert_match regexes[0], "a.b"
  end

  # used? tests - each way an attribute can be used

  def test_used_for_getter_call
    assert_used "name", "puts user.name"
  end

  def test_used_for_getter_without_receiver
    assert_used "name", "puts name"
  end

  def test_used_for_setter_call
    assert_used "name", "self.name = value"
  end

  def test_used_for_instance_variable_read
    # The case that proves the split: the ivar pattern is the only one that
    # matches, so dropping it would report this attribute as unused.
    assert_used "name", "def to_s\n  @name\nend\n"
  end

  def test_used_for_instance_variable_write
    assert_used "name", "@name = value"
  end

  def test_used_when_only_the_ivar_appears_and_never_the_bare_name
    assert_used "total", "  @total = 0\n  @total += 1\n"
  end

  def test_used_when_only_the_bare_name_appears_and_never_the_ivar
    assert_used "total", "  puts total\n"
  end

  def test_used_at_the_very_start_of_the_source
    assert_used "name", "name"
  end

  def test_used_at_the_very_end_of_the_source
    assert_used "name", "puts user.name"
  end

  # used? tests - what must not count as usage

  def test_not_used_for_attr_accessor_declaration_alone
    refute_used "name", "attr_accessor :name\n"
  end

  def test_not_used_for_attr_reader_declaration_alone
    refute_used "name", "attr_reader :name\n"
  end

  def test_not_used_for_attr_writer_declaration_alone
    refute_used "name", "attr_writer :name\n"
  end

  def test_not_used_for_symbol_reference_alone
    refute_used "name", "validates :name\n"
  end

  def test_not_used_for_partial_word
    refute_used "name", "username = 1\n"
  end

  def test_not_used_for_partial_instance_variable
    refute_used "name", "@username = 1\n"
  end

  def test_not_used_for_longer_name_with_the_attribute_as_a_suffix
    refute_used "name", "  @full_name = 1\n"
  end

  def test_not_used_for_capitalised_occurrence
    refute_used "name", "Name = 1\n"
  end

  def test_not_used_when_absent
    refute_used "name", "class User\nend\n"
  end

  def test_not_used_for_empty_source
    refute_used "name", ""
  end

  # used? tests - the declaration plus a real use

  def test_used_when_declaration_and_getter_both_appear
    refute_used "name", "attr_reader :name\n"
    assert_used "name", "attr_reader :name\nputs user.name\n"
  end

  def test_used_when_declaration_and_ivar_both_appear
    assert_used "name", "attr_reader :name\n@name = 1\n"
  end

  # used? tests - equivalence over a broad table

  def test_used_agrees_with_usage_regex_across_many_shapes
    names = ["name", "count", "value", "id", "a", "full_name", "_private", "name2"]
    sources = [
      "", "name", "@name", ":name", "user.name", "self.name = 1", "username", "@username",
      "attr_accessor :name", "attr_reader :count", "attr_writer :value", "full_name",
      "@full_name", "a", "@a", "a.b", "name2", "@name2", "_private", "@_private",
      "id\nname\n@count\n", "NAME", "Name", "name!", "name?", "name=", "[name]",
      "{ name: 1 }", "hash[:name]", "def name; end", "def self.name; end",
      "# name\n", "\"name\"", "'name'", "%w[name]", "send(:name)", "obj&.name",
      "name ||= 1", "@name ||= 1", "namespace", "renamed", "@renamed"
    ]

    names.each do |name|
      sources.each { |source| assert_equivalent name, source }
    end
  end

  def test_used_agrees_with_usage_regex_on_generated_input
    random = Random.new(1234)
    alphabet = %w[name count @name @count :name username self.name = ( ) . \n foo]

    200.times do
      name = %w[name count value].sample(random: random)
      source = Array.new(random.rand(1..12)) { alphabet.sample(random: random) }.join(" ")

      assert_equivalent name, source
    end
  end
end
