# frozen_string_literal: true

require "test_helper"
require "tempfile"

class BaselineTest < Minitest::Test
  def test_exists_returns_false_when_path_is_nil
    baseline = Keela::Baseline.new(nil)
    refute baseline.exists?
  end

  def test_exists_returns_false_when_file_does_not_exist
    baseline = Keela::Baseline.new("/nonexistent/path.yml")
    refute baseline.exists?
  end

  def test_exists_returns_true_when_file_exists
    Tempfile.create(["baseline", ".yml"]) do |f|
      f.write("---\n{}")
      f.close
      baseline = Keela::Baseline.new(f.path)
      assert baseline.exists?
    end
  end

  def test_load_returns_empty_hash_when_file_does_not_exist
    baseline = Keela::Baseline.new("/nonexistent/path.yml")
    assert_equal({}, baseline.load)
  end

  def test_load_parses_yaml_file
    Tempfile.create(["baseline", ".yml"]) do |f|
      f.write("methods:\n  app/models/user.rb:\n    - foo\n")
      f.close
      baseline = Keela::Baseline.new(f.path)
      expected = { "methods" => { "app/models/user.rb" => ["foo"] } }
      assert_equal expected, baseline.load
    end
  end

  def test_get_returns_empty_hash_for_missing_strategy
    baseline = Keela::Baseline.new(nil)
    assert_equal({}, baseline.get("methods"))
  end

  def test_get_returns_strategy_section
    Tempfile.create(["baseline", ".yml"]) do |f|
      f.write("methods:\n  app/models/user.rb:\n    - foo\nscopes:\n  app/models/post.rb:\n    - bar\n")
      f.close
      baseline = Keela::Baseline.new(f.path)
      baseline.load

      assert_equal({ "app/models/user.rb" => ["foo"] }, baseline.get("methods"))
      assert_equal({ "app/models/post.rb" => ["bar"] }, baseline.get("scopes"))
    end
  end

  def test_set_stores_strategy_data
    baseline = Keela::Baseline.new(nil)
    baseline.set("methods", { "app/models/user.rb" => ["foo"] })

    assert_equal({ "app/models/user.rb" => ["foo"] }, baseline.get("methods"))
  end

  def test_set_sorts_data_by_file_path
    baseline = Keela::Baseline.new(nil)
    baseline.set("methods", {
      "z_file.rb" => ["method_z"],
      "a_file.rb" => ["method_a"]
    })

    keys = baseline.get("methods").keys
    assert_equal %w[a_file.rb z_file.rb], keys
  end

  def test_save_writes_yaml_file
    Tempfile.create(["baseline", ".yml"]) do |f|
      f.close
      baseline = Keela::Baseline.new(f.path)
      baseline.set("methods", { "app/models/user.rb" => ["foo"] })
      baseline.set("scopes", { "app/models/post.rb" => ["bar"] })
      baseline.save

      content = File.read(f.path)
      assert_includes content, "methods:"
      assert_includes content, "scopes:"
      assert_includes content, "app/models/user.rb"
      assert_includes content, "foo"
    end
  end

  def test_save_includes_header_comment
    Tempfile.create(["baseline", ".yml"]) do |f|
      f.close
      baseline = Keela::Baseline.new(f.path)
      baseline.set("methods", { "app/models/user.rb" => ["foo"] })
      baseline.save

      content = File.read(f.path)
      assert_includes content, "# Unused code identified by Keela"
    end
  end

  def test_save_does_nothing_when_path_is_nil
    baseline = Keela::Baseline.new(nil)
    baseline.set("methods", { "app/models/user.rb" => ["foo"] })

    # Should not raise
    baseline.save
  end

  def test_set_preserves_existing_data_from_file
    Tempfile.create(["baseline", ".yml"]) do |f|
      # Write initial data with scopes
      f.write("scopes:\n  app/models/post.rb:\n    - existing_scope\n")
      f.close

      # Create new baseline instance and set methods
      baseline = Keela::Baseline.new(f.path)
      baseline.set("methods", { "app/models/user.rb" => ["new_method"] })
      baseline.save

      # Verify both sections exist
      content = File.read(f.path)
      assert_includes content, "scopes:"
      assert_includes content, "existing_scope"
      assert_includes content, "methods:"
      assert_includes content, "new_method"
    end
  end
end
