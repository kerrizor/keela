# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"
require "open3"
require "json"

class CLITest < Minitest::Test
  KEELA_ROOT = File.expand_path("../..", __FILE__)
  KEELA_EXE = File.join(KEELA_ROOT, "exe", "keela")
  KEELA_LIB = File.join(KEELA_ROOT, "lib")

  def test_cli_excluded_option_overrides_config_file
    in_tmpdir do
      setup_test_files

      # Create a config file that sets excluded_path
      File.write("keela.yml", <<~YAML)
        excluded_path: "config_excluded.yml"
      YAML

      # Create the config file's exclusion (excludes nothing)
      File.write("config_excluded.yml", "---\n{}")

      # Create a CLI exclusion file that excludes our method
      File.write("cli_excluded.yml", <<~YAML)
        "app/models/user.rb":
          - unused_method: "Excluded via CLI"
      YAML

      # Run without CLI override - should find unused_method
      stdout, stderr, status = run_keela("--report")
      assert status.success?, "Command should succeed: #{stderr}"
      assert_match(/unused_method/, stdout, "Should find unused_method when using config file exclusions")

      # Run with CLI override - should NOT find unused_method
      stdout, stderr, status = run_keela("--report", "--excluded", "cli_excluded.yml")
      assert status.success?, "Command should succeed: #{stderr}"
      assert_match(/No unused methods/, stdout, "Should not find unused_method when CLI excludes it")
    end
  end

  def test_cli_baseline_option_overrides_config_file
    in_tmpdir do
      setup_test_files

      # Create a config file that sets baseline_path to a non-matching baseline
      File.write("keela.yml", <<~YAML)
        baseline_path: "config_baseline.yml"
      YAML

      # Create the config file's baseline (empty - will cause failure due to new unused)
      File.write("config_baseline.yml", "---\n{}")

      # Create a CLI baseline that includes our method (matches current state)
      File.write("cli_baseline.yml", <<~YAML)
        methods:
          "app/models/user.rb":
            - unused_method
      YAML

      # Run without CLI override - should fail (new unused code detected)
      _stdout, _stderr, status = run_keela("--quiet")
      refute status.success?, "Should fail when config baseline is empty but unused code exists"

      # Run with CLI override pointing to baseline with our method
      # Should pass (no new unused, no removed)
      _stdout, stderr, status = run_keela("--quiet", "--baseline", "cli_baseline.yml")
      assert status.success?, "Should pass when CLI baseline matches current state: #{stderr}"
    end
  end

  def test_cli_extensions_option_overrides_config_file
    in_tmpdir do
      setup_test_files

      # Create a config file that only scans .txt files
      File.write("keela.yml", <<~YAML)
        extensions:
          - txt
      YAML

      # Run without CLI override - should find nothing (no .txt files)
      stdout, stderr, status = run_keela("--report")
      assert status.success?, "Command should succeed: #{stderr}"
      assert_match(/No unused methods/, stdout, "Should find nothing when config limits to .txt")

      # Run with CLI override - should find unused_method
      stdout, stderr, status = run_keela("--report", "--extensions", "rb")
      assert status.success?, "Command should succeed: #{stderr}"
      assert_match(/unused_method/, stdout, "Should find unused_method when CLI sets .rb extension")
    end
  end

  def test_baseline_reports_unused_code_from_every_strategy
    in_tmpdir do
      setup_multiple_strategy_files

      stdout, stderr, status = run_keela("--type", "methods,scopes,constants")

      assert_equal 1, status.exitstatus, stderr
      assert_includes stdout, "unused_method"
      assert_includes stdout, "unused_scope"
      assert_includes stdout, "UNUSED_CONSTANT"
    end
  end

  def test_baseline_json_includes_every_strategy_after_a_failure
    in_tmpdir do
      setup_multiple_strategy_files

      stdout, stderr, status = run_keela("--type", "methods,scopes,constants", "--format", "json")

      assert_equal 1, status.exitstatus, stderr
      result = JSON.parse(stdout)
      assert_equal ["unused_method"], result.dig("unused", "methods", "app/models/user.rb")
      assert_equal ["unused_scope"], result.dig("unused", "scopes", "app/models/user.rb")
      assert_equal ["UNUSED_CONSTANT"], result.dig("unused", "constants", "app/models/user.rb")
      assert_equal 3, result.dig("summary", "total")
    end
  end

  def test_successful_later_strategy_does_not_clear_baseline_failure
    in_tmpdir do
      setup_test_files
      File.write(".keela_baseline.yml", "---\n{}")

      stdout, stderr, status = run_keela("--type", "methods,scopes")

      assert_equal 1, status.exitstatus, stderr
      assert_includes stdout, "unused_method"
    end
  end

  def test_reports_stale_exclusion_during_baseline_run_and_exits_nonzero
    in_tmpdir do
      setup_clean_model_with_stale_exclusion

      stdout, stderr, status = run_keela("--excluded", "excluded.yml")

      assert_equal 1, status.exitstatus, stderr
      assert_match(/stale methods exclusion/, stdout)
      assert_match(/vanished_method/, stdout)
    end
  end

  def test_json_output_includes_stale_exclusions
    in_tmpdir do
      setup_clean_model_with_stale_exclusion

      stdout, stderr, status = run_keela("--excluded", "excluded.yml", "--format", "json")

      assert_equal 1, status.exitstatus, stderr
      result = JSON.parse(stdout)
      assert_equal ["vanished_method"],
        result.dig("stale_exclusions", "methods", "app/models/user.rb")
    end
  end

  private

  def setup_clean_model_with_stale_exclusion
    FileUtils.mkdir_p("app/models")
    File.write("app/models/user.rb", <<~RUBY)
      class User
        def real_method
        end

        def uses_it
          real_method
        end
      end
    RUBY
    File.write(".keela_baseline.yml", "---\n{}")
    File.write("excluded.yml", <<~YAML)
      methods:
        "app/models/user.rb":
          - vanished_method: "Used dynamically"
    YAML
  end

  def setup_multiple_strategy_files
    FileUtils.mkdir_p("app/models")
    File.write("app/models/user.rb", <<~RUBY)
      class User
        scope :unused_scope, -> { all }
        UNUSED_CONSTANT = 1

        def unused_method
        end
      end
    RUBY
    File.write(".keela_baseline.yml", "---\n{}")
  end

  def in_tmpdir
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        yield
      end
    end
  end

  def setup_test_files
    FileUtils.mkdir_p("app/models")
    File.write("app/models/user.rb", "def unused_method\nend\n")
  end

  def run_keela(*args)
    env = { "RUBYLIB" => KEELA_LIB }
    cmd = ["ruby", KEELA_EXE, "--type", "methods"] + args

    Open3.capture3(env, *cmd)
  end
end
