# frozen_string_literal: true

module Keela
  # The concatenated source that usage detection is matched against, plus
  # lazily-derived views of it.
  #
  # Built once and shared by every strategy in a run. Derived views are memoized
  # because they cost about as much as a single usage check but are identical for
  # every definition in the run.
  #
  class Source
    # The ASCII block as a String#delete range. Built from its code points
    # rather than written as a literal so that this file stays free of the
    # control characters the range ends in.
    ASCII_RANGE = [0x00, 0x7F].map { |code_point| code_point.chr(Encoding::UTF_8) }.join("-").freeze

    attr_reader :text

    def initialize(text)
      @text = text
    end

    # Build from the scanner's { filename => [lines] } hash.
    def self.from_source_files(source_files)
      new(source_files.values.flatten.join)
    end

    # Unicode full case folding of #text.
    #
    # Lets a strategy drop //i from its pattern and match case-sensitively
    # against this instead, which avoids a sharp performance cliff.
    #
    # Only three ASCII fold targets have a non-ASCII source: U+017F folds to
    # "s", U+212A folds to "k", and the eszett folds to "ss". So once the string
    # being searched is not entirely 7-bit ASCII, a //i pattern whose literal
    # BEGINS with "s" or "k" can no longer be found with a plain byte search,
    # and takes 100x longer or worse. A literal with "s" in the middle is partly
    # affected; one ending in "s" is not.
    #
    # A single non-ASCII character in any scanned file is enough to put a whole
    # run on that path, and method names beginning with "s" are common, so this
    # is easy to hit by accident.
    #
    # Full folding, not #downcase, because //i folds too: /strasse/i matches the
    # eszett spelling of "STRASSE".
    #
    def folded
      @folded ||= text.downcase(:fold)
    end

    # Whether matching a folded ASCII literal against #folded decides exactly
    # what matching that literal against #text under //i would decide.
    #
    # Two things can break the equivalence, both only reachable with non-ASCII
    # text:
    #
    # - A character that folds to more than one character (an eszett folds to
    #   "ss") shifts everything after it, so a pattern's lookarounds see
    #   different neighbours than they would in #text. Folding never maps a
    #   character to nothing, so an unchanged total length proves every
    #   character mapped to exactly one and positions are preserved.
    #
    # - A character that folds into ASCII (U+212A KELVIN SIGN folds to "k",
    #   U+017F LATIN SMALL LETTER LONG S folds to "s") puts ASCII letters in the
    #   folded view where #text had none. A guard such as (?<![a-z_]) would then
    #   see a letter that //i never matches in #text.
    #
    # Neither occurs in ASCII-only text, so this holds for essentially all code.
    # Strategies fall back to their //i pattern when it does not.
    #
    def fold_preserves_matching?
      return @fold_preserves_matching if defined?(@fold_preserves_matching)

      @fold_preserves_matching = folded.length == text.length && !non_ascii_folds_into_ascii?
    end

    private

    def non_ascii_folds_into_ascii?
      non_ascii_characters.downcase(:fold).match?(/[[:ascii:]]/)
    end

    # Only the non-ASCII characters of #text, which is a tiny string even for a
    # large codebase.
    #
    # #delete with a character range rather than a regexp: a regexp scan of a
    # string this size costs seconds, this costs milliseconds.
    #
    def non_ascii_characters
      text.delete(ASCII_RANGE)
    end
  end
end
