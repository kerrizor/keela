# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class ExclusionValidatorTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @original_dir = Dir.pwd
    Dir.chdir(@tmpdir)

    FileUtils.mkdir_p("app/models")
    File.write("app/models/user.rb", <<~RUBY)
      class User
        def existing_method
        end

        scope :active, -> { where(active: true) }
      end
    RUBY
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.remove_entry(@tmpdir)
  end

  def test_validates_existing_method
    File.write("excluded.yml", <<~YAML)
      methods:
        "app/models/user.rb":
          - existing_method: "reason"
    YAML

    validator = Keela::ExclusionValidator.new("excluded.yml")

    assert_output(/Valid exclusions/) do
      result = validator.validate
      assert result
    end

    assert_equal 1, validator.results[:valid].size
    assert_empty validator.results[:stale]
  end

  def test_detects_stale_method
    File.write("excluded.yml", <<~YAML)
      methods:
        "app/models/user.rb":
          - nonexistent_method: "reason"
    YAML

    validator = Keela::ExclusionValidator.new("excluded.yml")

    assert_output(/Stale exclusions found/) do
      result = validator.validate
      refute result
    end

    assert_empty validator.results[:valid]
    assert_equal 1, validator.results[:stale].size
    assert_equal "no definition found", validator.results[:stale].first[:error]
  end

  def test_detects_missing_file
    File.write("excluded.yml", <<~YAML)
      methods:
        "app/models/nonexistent.rb":
          - some_method: "reason"
    YAML

    validator = Keela::ExclusionValidator.new("excluded.yml")

    assert_output(/Stale exclusions found/) do
      result = validator.validate
      refute result
    end

    assert_equal "file not found", validator.results[:stale].first[:error]
  end

  def test_validates_scope
    File.write("excluded.yml", <<~YAML)
      scopes:
        "app/models/user.rb":
          - active: "reason"
    YAML

    validator = Keela::ExclusionValidator.new("excluded.yml")

    assert_output(/Valid exclusions/) do
      result = validator.validate
      assert result
    end

    assert_equal 1, validator.results[:valid].size
  end

  def test_returns_false_for_missing_exclusion_file
    validator = Keela::ExclusionValidator.new("nonexistent.yml")

    assert_output(/not found/) do
      result = validator.validate
      refute result
    end
  end
end
