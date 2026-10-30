# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class ExclusionNormalizerTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @original_dir = Dir.pwd
    Dir.chdir(@tmpdir)
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.remove_entry(@tmpdir)
  end

  def test_sorts_strategy_aware_format_at_all_three_levels
    File.write("excluded.yml", <<~YAML)
      scopes:
        "app/models/zebra.rb":
          - zoo: "z"
          - apple: "a"
      methods:
        "app/models/user.rb":
          - charlie: "c"
          - alpha: "a"
        "app/models/account.rb":
          - beta: "b"
    YAML

    normalizer = Keela::ExclusionNormalizer.new("excluded.yml")
    assert_output(/Normalized/) { assert normalizer.normalize }

    expected = <<~YAML
      ---
      methods:
        app/models/account.rb:
        - beta: b
        app/models/user.rb:
        - alpha: a
        - charlie: c
      scopes:
        app/models/zebra.rb:
        - apple: a
        - zoo: z
    YAML

    assert_equal expected, strip_header(File.read("excluded.yml"))
  end

  def test_sorts_legacy_flat_format_at_two_levels
    File.write("excluded.yml", <<~YAML)
      "app/models/zebra.rb":
        - zoo: "z"
        - apple: "a"
      "app/models/account.rb":
        - beta: "b"
    YAML

    normalizer = Keela::ExclusionNormalizer.new("excluded.yml")
    assert_output(/Normalized/) { assert normalizer.normalize }

    expected = <<~YAML
      ---
      app/models/account.rb:
        - beta: b
      app/models/zebra.rb:
        - apple: a
        - zoo: z
    YAML

    assert_equal expected, strip_header(File.read("excluded.yml"))
  end

  def test_is_idempotent
    File.write("excluded.yml", <<~YAML)
      methods:
        "app/models/user.rb":
          - charlie: "c"
          - alpha: "a"
    YAML

    normalizer = Keela::ExclusionNormalizer.new("excluded.yml")
    assert_output(/Normalized/) { normalizer.normalize }
    first = File.read("excluded.yml")

    assert_output(/Normalized/) { Keela::ExclusionNormalizer.new("excluded.yml").normalize }
    second = File.read("excluded.yml")

    assert_equal first, second, "Normalizing twice must yield byte-identical output"
  end

  def test_preserves_reason_containing_a_colon
    File.write("excluded.yml", <<~YAML)
      methods:
        "app/models/user.rb":
          - some_method: "Called via Foo::Bar metaprogramming: see note"
    YAML

    normalizer = Keela::ExclusionNormalizer.new("excluded.yml")
    assert_output(/Normalized/) { normalizer.normalize }

    reloaded = YAML.load_file("excluded.yml")
    reason = reloaded.dig("methods", "app/models/user.rb").first["some_method"]
    assert_equal "Called via Foo::Bar metaprogramming: see note", reason

    # A reason with a colon must stay quoted so the YAML round-trips.
    assert_match(/some_method: ['"]Called via Foo::Bar/, File.read("excluded.yml"))
  end

  def test_emits_string_keys_not_symbols
    File.write("excluded.yml", <<~YAML)
      methods:
        "app/models/user.rb":
          - alpha: "a"
    YAML

    normalizer = Keela::ExclusionNormalizer.new("excluded.yml")
    assert_output(/Normalized/) { normalizer.normalize }

    content = File.read("excluded.yml")
    refute_match(/^:methods:/, content, "Top-level keys must be strings, not :symbols")
    refute_match(/^  :/, content, "File keys must be strings, not :symbols")

    reloaded = YAML.load_file("excluded.yml")
    assert_equal ["methods"], reloaded.keys
  end

  def test_missing_file_returns_false
    normalizer = Keela::ExclusionNormalizer.new("does_not_exist.yml")

    assert_output(/not found/) do
      refute normalizer.normalize
    end
  end

  def test_empty_file_writes_empty_yaml_and_succeeds
    File.write("excluded.yml", "---\n{}\n")

    normalizer = Keela::ExclusionNormalizer.new("excluded.yml")
    assert_output(/Normalized/) { assert normalizer.normalize }

    assert_equal "---\n{}\n", strip_header(File.read("excluded.yml"))
  end

  private

  # Strips the generated comment header, returning just the YAML body.
  #
  def strip_header(content)
    content.lines.reject { |line| line.start_with?("#") }.join
  end
end
