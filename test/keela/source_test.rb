# frozen_string_literal: true

require "test_helper"

class SourceTest < Minitest::Test
  # Written as code-point escapes: these characters are the point of the test,
  # and several are invisible or easily mistaken for an ASCII letter.
  ESZETT = "\u00DF"                    # folds to "ss", two characters
  DOTTED_CAPITAL_I = "\u0130"          # folds to "i" + combining dot above
  KELVIN_SIGN = "\u212A"               # folds to ASCII "k"
  LONG_S = "\u017F"                    # folds to ASCII "s"
  U_UMLAUT_CAPITAL = "\u00DC"          # folds to a non-ASCII character
  FF_LIGATURE = "\uFB00"               # folds to "ff", two characters

  # source

  def test_exposes_source
    assert_equal "attr_reader :name", Keela::Source.new("attr_reader :name").text
  end

  def test_from_source_files_joins_every_line_of_every_file
    source = Keela::Source.from_source_files(
      "app/models/user.rb" => ["class User\n", "  attr_reader :name\n", "end\n"],
      "app/models/post.rb" => ["class Post\n", "end\n"]
    )

    assert_equal "class User\n  attr_reader :name\nend\nclass Post\nend\n", source.text
  end

  def test_from_source_files_handles_no_files
    assert_equal "", Keela::Source.from_source_files({}).text
  end

  def test_from_source_files_prevents_cross_file_boundary_matches
    # Regression for issue #83: the last line of file A may lack a trailing
    # newline, so joining files with no separator glues it onto the first line
    # of file B and manufactures a usage that exists in no single file.
    #
    source = Keela::Source.from_source_files(
      "app/views/users/index.html.erb" => ["<%= render \"users/for"],
      "app/views/users/show.html.erb" => ["m\" %>\n"]
    )

    refute_includes source.text, "render \"users/form\""
    assert_includes source.text, "users/for\nm"
  end

  def test_from_source_files_treats_an_empty_file_as_no_contribution
    # An empty file is an empty line array; it must add nothing, not a stray
    # newline, and must not swallow the separator between its neighbours.
    #
    source = Keela::Source.from_source_files(
      "app/models/user.rb" => ["class User\nend\n"],
      "app/models/empty.rb" => [],
      "app/models/post.rb" => ["class Post\nend\n"]
    )

    assert_equal "class User\nend\nclass Post\nend\n", source.text
  end

  def test_from_source_files_does_not_double_separate_files_ending_in_newline
    source = Keela::Source.from_source_files(
      "app/models/user.rb" => ["class User\n", "end\n"],
      "app/models/post.rb" => ["class Post\n", "end\n"]
    )

    refute_includes source.text, "\n\n"
  end

  def test_from_source_files_across_files_stays_foldable_with_non_ascii
    # The synthesized boundary newlines must not perturb the fold-length
    # invariant fold_preserves_matching? relies on, even with non-ASCII text.
    #
    source = Keela::Source.from_source_files(
      "app/models/user.rb" => ["# café\n"],
      "app/models/post.rb" => ["class Post\nend\n"]
    )

    assert_predicate source, :fold_preserves_matching?
  end

  # folded

  def test_folded_downcases_ascii
    assert_equal "user.name", Keela::Source.new("User.NAME").folded
  end

  def test_folded_uses_full_case_folding_not_downcase
    # This is why #folded uses downcase(:fold): //i folds too, so /strasse/i
    # matches the eszett spelling and a plain #downcase would not.
    source = Keela::Source.new("STRA#{ESZETT}E")

    assert_equal "strasse", source.folded
    assert_match(/strasse/i, source.text)
  end

  def test_folded_is_memoized
    source = Keela::Source.new("NAME")

    assert_same source.folded, source.folded
  end

  def test_folded_leaves_source_untouched
    source = Keela::Source.new("User.NAME")
    source.folded

    assert_equal "User.NAME", source.text
  end

  # fold_preserves_matching?

  def test_foldable_for_ascii_source
    assert_predicate Keela::Source.new("attr_reader :name\nuser.name\n"), :fold_preserves_matching?
  end

  def test_foldable_for_empty_source
    assert_predicate Keela::Source.new(""), :fold_preserves_matching?
  end

  def test_foldable_for_non_ascii_that_folds_to_itself
    # Accented characters are everywhere in comments and fixtures; they must not
    # cost the fast path.
    assert_predicate Keela::Source.new("# café éèê\nuser.name\n"), :fold_preserves_matching?
  end

  def test_foldable_for_non_ascii_that_folds_to_other_non_ascii
    assert_predicate Keela::Source.new("#{U_UMLAUT_CAPITAL}ber\nuser.name\n"), :fold_preserves_matching?
  end

  def test_not_foldable_when_a_character_expands
    # Position-shifting fold: one character becomes two.
    refute_predicate Keela::Source.new("STRA#{ESZETT}E"), :fold_preserves_matching?
  end

  def test_not_foldable_when_a_ligature_expands
    refute_predicate Keela::Source.new("o#{FF_LIGATURE}ice"), :fold_preserves_matching?
  end

  def test_not_foldable_when_dotted_capital_i_expands
    refute_predicate Keela::Source.new("#{DOTTED_CAPITAL_I}stanbul"), :fold_preserves_matching?
  end

  def test_not_foldable_when_non_ascii_folds_into_ascii
    # Length is preserved here, so only the second condition rejects it.
    source = Keela::Source.new("#{KELVIN_SIGN}elvin")

    assert_equal source.text.length, source.folded.length
    refute_predicate source, :fold_preserves_matching?
  end

  def test_not_foldable_for_long_s
    refute_predicate Keela::Source.new("#{LONG_S}omething"), :fold_preserves_matching?
  end

  def test_foldable_is_memoized
    source = Keela::Source.new("user.name")
    source.fold_preserves_matching?

    assert_predicate source, :fold_preserves_matching?
  end
end
