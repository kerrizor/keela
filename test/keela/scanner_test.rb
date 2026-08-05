# frozen_string_literal: true

require "test_helper"

class ScannerTest < Minitest::Test
  def setup
    @strategy = Keela::Strategies::Methods.new
    @config = Keela::Configuration.new
    @scanner = Keela::Scanner.new(strategy: @strategy, configuration: @config)
  end

  def test_initializes_with_strategy
    assert_equal @strategy, @scanner.strategy
  end

  def test_initializes_with_configuration
    assert_equal @config, @scanner.configuration
  end

  def test_initializes_empty_source_files
    assert_empty @scanner.source_files
  end

  def test_initializes_empty_unused_collection
    assert_empty @scanner.unused_collection
  end

  def test_initializes_empty_new_unused
    assert_empty @scanner.new_unused
  end

  def test_initializes_empty_removed
    assert_empty @scanner.removed
  end

  def test_file_globs_includes_rb_files
    assert_includes @scanner.file_globs, "app/**/*.rb"
  end

  def test_file_globs_includes_haml_files
    assert_includes @scanner.file_globs, "app/**/*.haml"
  end

  def test_file_globs_includes_erb_files
    assert_includes @scanner.file_globs, "app/**/*.erb"
  end

  def test_file_globs_searches_app_lib_and_config
    globs = @scanner.file_globs

    assert globs.any? { |g| g.start_with?("app/") }
    assert globs.any? { |g| g.start_with?("lib/") }
    assert globs.any? { |g| g.start_with?("config/") }
  end

  def test_run_returns_true_when_required_directory_missing
    @config.required_directory = "nonexistent_directory"

    assert @scanner.run
  end

end

class ScannerWithMockedFilesTest < Minitest::Test
  def setup
    @strategy = Keela::Strategies::Methods.new
    @config = Keela::Configuration.new
    @scanner = Keela::Scanner.new(strategy: @strategy, configuration: @config)
  end

  def test_finds_unused_methods
    # Simulate source files
    @scanner.instance_variable_set(:@source_files, {
      "app/models/user.rb" => [
        "def used_method\n",
        "def unused_method\n"
      ],
      "app/models/post.rb" => [
        "used_method\n"  # This uses used_method
      ]
    })

    # Run the private find_definitions method
    definitions = @scanner.send(:find_definitions)

    assert_equal 2, definitions.size
    assert definitions.any? { |d| d[:name] == "used_method" }
    assert definitions.any? { |d| d[:name] == "unused_method" }
  end
end

class ScannerCommentHandlingTest < Minitest::Test
  def test_methods_strategy_includes_commented_methods
    strategy = Keela::Strategies::Methods.new
    config = Keela::Configuration.new
    scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

    scanner.instance_variable_set(:@source_files, {
      "app/models/user.rb" => [
        "# def old_method\n",
        "def active_method\n"
      ]
    })

    definitions = scanner.send(:find_definitions)

    # Methods strategy does NOT skip commented lines
    assert_equal 2, definitions.size
    assert definitions.any? { |d| d[:name] == "old_method" }
    assert definitions.any? { |d| d[:name] == "active_method" }
  end

  def test_scopes_strategy_skips_commented_scopes
    strategy = Keela::Strategies::Scopes.new
    config = Keela::Configuration.new
    scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

    scanner.instance_variable_set(:@source_files, {
      "app/models/user.rb" => [
        "# scope :old_scope, -> { }\n",
        "scope :active_scope, -> { }\n"
      ]
    })

    definitions = scanner.send(:find_definitions)

    # Scopes strategy DOES skip commented lines
    assert_equal 1, definitions.size
    assert definitions.any? { |d| d[:name] == "active_scope" }
    refute definitions.any? { |d| d[:name] == "old_scope" }
  end
end

class ScannerExcludePatternsTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @original_dir = Dir.pwd
    Dir.chdir(@tmpdir)

    # Create test file structure
    FileUtils.mkdir_p("app/models")
    FileUtils.mkdir_p("vendor/gems")
    FileUtils.mkdir_p("tmp/cache")

    File.write("app/models/user.rb", "def user_method\nend\n")
    File.write("vendor/gems/foo.rb", "def vendor_method\nend\n")
    File.write("tmp/cache/bar.rb", "def tmp_method\nend\n")
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@tmpdir)
  end

  def test_exclude_patterns_filters_out_matching_files
    config = Keela::Configuration.new
    config.directory_patterns = %w[**/*.rb]
    config.exclude_patterns = %w[vendor/**/* tmp/**/*]

    strategy = Keela::Strategies::Methods.new
    scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

    # Access file_globs and then load files
    scanner.send(:load_source_files)

    # Should only have app/models/user.rb, not vendor or tmp files
    assert_includes scanner.source_files.keys, "app/models/user.rb"
    refute scanner.source_files.keys.any? { |f| f.start_with?("vendor/") }
    refute scanner.source_files.keys.any? { |f| f.start_with?("tmp/") }
  end

  def test_exclude_patterns_with_no_exclusions_includes_all_files
    config = Keela::Configuration.new
    config.directory_patterns = %w[**/*.rb]
    config.exclude_patterns = []

    strategy = Keela::Strategies::Methods.new
    scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

    scanner.send(:load_source_files)

    assert_includes scanner.source_files.keys, "app/models/user.rb"
    assert_includes scanner.source_files.keys, "vendor/gems/foo.rb"
    assert_includes scanner.source_files.keys, "tmp/cache/bar.rb"
  end

  def test_exclude_patterns_with_specific_file_pattern
    config = Keela::Configuration.new
    config.directory_patterns = %w[**/*.rb]
    config.exclude_patterns = %w[**/foo.rb]

    strategy = Keela::Strategies::Methods.new
    scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

    scanner.send(:load_source_files)

    assert_includes scanner.source_files.keys, "app/models/user.rb"
    refute_includes scanner.source_files.keys, "vendor/gems/foo.rb"
    assert_includes scanner.source_files.keys, "tmp/cache/bar.rb"
  end
end

class ScannerIncludePatternsTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @original_dir = Dir.pwd
    Dir.chdir(@tmpdir)

    # Create test file structure
    FileUtils.mkdir_p("app/models")
    FileUtils.mkdir_p("lib")
    FileUtils.mkdir_p("engines/billing/app/models")
    FileUtils.mkdir_p("custom/services")

    File.write("app/models/user.rb", "def user_method\nend\n")
    File.write("lib/utils.rb", "def lib_method\nend\n")
    File.write("engines/billing/app/models/invoice.rb", "def invoice_method\nend\n")
    File.write("custom/services/payment.rb", "def payment_method\nend\n")
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@tmpdir)
  end

  def test_include_patterns_adds_to_directory_patterns
    config = Keela::Configuration.new
    config.directory_patterns = %w[app/**/*.rb lib/**/*.rb]
    config.include_patterns = %w[engines/**/*.rb]

    strategy = Keela::Strategies::Methods.new
    scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

    scanner.send(:load_source_files)

    # Should have files from both directory_patterns AND include_patterns
    assert_includes scanner.source_files.keys, "app/models/user.rb"
    assert_includes scanner.source_files.keys, "lib/utils.rb"
    assert_includes scanner.source_files.keys, "engines/billing/app/models/invoice.rb"
    refute scanner.source_files.keys.any? { |f| f.start_with?("custom/") }
  end

  def test_include_patterns_with_multiple_patterns
    config = Keela::Configuration.new
    config.directory_patterns = %w[app/**/*.rb]
    config.include_patterns = %w[engines/**/*.rb custom/**/*.rb]

    strategy = Keela::Strategies::Methods.new
    scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

    scanner.send(:load_source_files)

    assert_includes scanner.source_files.keys, "app/models/user.rb"
    assert_includes scanner.source_files.keys, "engines/billing/app/models/invoice.rb"
    assert_includes scanner.source_files.keys, "custom/services/payment.rb"
    refute scanner.source_files.keys.any? { |f| f.start_with?("lib/") }
  end

  def test_include_patterns_empty_does_not_change_behavior
    config = Keela::Configuration.new
    config.directory_patterns = %w[app/**/*.rb]
    config.include_patterns = []

    strategy = Keela::Strategies::Methods.new
    scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

    scanner.send(:load_source_files)

    assert_includes scanner.source_files.keys, "app/models/user.rb"
    refute scanner.source_files.keys.any? { |f| f.start_with?("engines/") }
    refute scanner.source_files.keys.any? { |f| f.start_with?("custom/") }
  end

  def test_file_globs_includes_both_directory_and_include_patterns
    config = Keela::Configuration.new
    config.extensions = %w[rb]
    # Using default directory_patterns, adding include_patterns
    config.include_patterns = %w[engines/**/*.%<ext>s]

    strategy = Keela::Strategies::Methods.new
    scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

    globs = scanner.file_globs

    assert_includes globs, "app/**/*.rb"
    assert_includes globs, "engines/**/*.rb"
  end
end

class ScannerSilentModeTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @original_dir = Dir.pwd
    Dir.chdir(@tmpdir)

    FileUtils.mkdir_p("app/models")
    File.write("app/models/user.rb", "def unused_method\nend\n")
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@tmpdir)
  end

  def test_silent_mode_suppresses_output
    config = Keela::Configuration.new
    strategy = Keela::Strategies::Methods.new
    scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

    output = capture_io do
      scanner.run(force_report: true, silent: true)
    end

    assert_empty output[0], "Expected no stdout output in silent mode"
  end

  def test_silent_mode_still_populates_unused_collection
    config = Keela::Configuration.new
    strategy = Keela::Strategies::Methods.new
    scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

    scanner.run(force_report: true, silent: true)

    refute_empty scanner.unused_collection
    assert_includes scanner.unused_collection["app/models/user.rb"], "unused_method"
  end

  def test_non_silent_mode_produces_output
    config = Keela::Configuration.new
    strategy = Keela::Strategies::Methods.new
    scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

    output = capture_io do
      scanner.run(force_report: true, silent: false)
    end

    refute_empty output[0], "Expected stdout output in non-silent mode"
  end
end

class ScannerShowProgressTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @original_dir = Dir.pwd
    Dir.chdir(@tmpdir)

    FileUtils.mkdir_p("app/models")
    File.write("app/models/user.rb", "def unused_method\nend\n")
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@tmpdir)
  end

  def test_show_progress_false_suppresses_progress_bar
    config = Keela::Configuration.new
    config.show_progress = false
    strategy = Keela::Strategies::Methods.new
    scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

    # In report mode, progress would normally show, but show_progress=false should suppress it
    output = capture_io do
      scanner.run(force_report: true, silent: false)
    end

    # The output should contain the report but NOT progress bar output
    # Progress bar output contains "Checking methods" with ANSI codes
    refute_match(/Checking methods.*\r/, output[0], "Progress bar should be suppressed when show_progress is false")
  end

  def test_show_progress_true_allows_progress_bar_in_report_mode
    config = Keela::Configuration.new
    config.show_progress = true
    strategy = Keela::Strategies::Methods.new
    scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

    # This test just ensures the scanner runs without error when show_progress is true
    # Actually testing progress bar output is tricky due to TTY detection
    assert scanner.run(force_report: true, silent: false)
  end
end

class ScannerConfigurationValidationTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @original_dir = Dir.pwd
    Dir.chdir(@tmpdir)

    FileUtils.mkdir_p("app/models")
    File.write("app/models/user.rb", "def user_method\nend\n")
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@tmpdir)
  end

  def test_raises_error_when_custom_directory_patterns_with_include_patterns
    config = Keela::Configuration.new
    config.directory_patterns = %w[src/**/*.rb]  # Custom, not default
    config.include_patterns = %w[engines/**/*.rb]

    strategy = Keela::Strategies::Methods.new
    scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

    error = assert_raises(Keela::ConfigurationError) { scanner.run }
    assert_match(/Cannot use include_patterns or exclude_patterns with custom directory_patterns/, error.message)
  end

  def test_raises_error_when_custom_directory_patterns_with_exclude_patterns
    config = Keela::Configuration.new
    config.directory_patterns = %w[src/**/*.rb]  # Custom, not default
    config.exclude_patterns = %w[vendor/**/*]

    strategy = Keela::Strategies::Methods.new
    scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

    error = assert_raises(Keela::ConfigurationError) { scanner.run }
    assert_match(/Cannot use include_patterns or exclude_patterns with custom directory_patterns/, error.message)
  end

  def test_allows_default_directory_patterns_with_include_patterns
    config = Keela::Configuration.new
    # Using default directory_patterns
    config.include_patterns = %w[engines/**/*.rb]

    strategy = Keela::Strategies::Methods.new
    scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

    # Should not raise - this is the valid use case
    assert scanner.run
  end

  def test_allows_default_directory_patterns_with_exclude_patterns
    config = Keela::Configuration.new
    # Using default directory_patterns
    config.exclude_patterns = %w[vendor/**/*]

    strategy = Keela::Strategies::Methods.new
    scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

    # Should not raise - this is the valid use case
    assert scanner.run
  end

  def test_allows_custom_directory_patterns_without_include_or_exclude
    config = Keela::Configuration.new
    config.directory_patterns = %w[app/**/*.rb]  # Custom, but no include/exclude

    strategy = Keela::Strategies::Methods.new
    scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

    # Should not raise - full control mode without tweaks
    assert scanner.run
  end

  # resolve_excluded_path tests

  def test_resolve_excluded_path_returns_configured_path_when_file_exists
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        File.write("custom_excluded.yml", "---\n{}")

        config = Keela::Configuration.new
        config.excluded_path = "custom_excluded.yml"
        scanner = Keela::Scanner.new(strategy: @strategy, configuration: config)

        assert_equal "custom_excluded.yml", scanner.send(:resolve_excluded_path)
      end
    end
  end

  def test_resolve_excluded_path_returns_nil_when_configured_path_does_not_exist
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        config = Keela::Configuration.new
        config.excluded_path = "nonexistent.yml"
        scanner = Keela::Scanner.new(strategy: @strategy, configuration: config)

        assert_nil scanner.send(:resolve_excluded_path)
      end
    end
  end

  def test_resolve_excluded_path_prefers_keela_directory
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        Dir.mkdir(".keela")
        File.write(".keela/excluded.yml", "---\n{}")
        File.write("keela_excluded.yml", "---\n{}")

        config = Keela::Configuration.new
        scanner = Keela::Scanner.new(strategy: @strategy, configuration: config)

        assert_equal ".keela/excluded.yml", scanner.send(:resolve_excluded_path)
      end
    end
  end

  def test_resolve_excluded_path_falls_back_to_root_file
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        File.write("keela_excluded.yml", "---\n{}")

        config = Keela::Configuration.new
        scanner = Keela::Scanner.new(strategy: @strategy, configuration: config)

        assert_equal "keela_excluded.yml", scanner.send(:resolve_excluded_path)
      end
    end
  end

  def test_resolve_excluded_path_returns_nil_when_no_files_exist
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        config = Keela::Configuration.new
        scanner = Keela::Scanner.new(strategy: @strategy, configuration: config)

        assert_nil scanner.send(:resolve_excluded_path)
      end
    end
  end

  # filter_excluded tests

  def test_filter_excluded_with_strategy_aware_format
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        # Strategy-aware format: grouped by strategy name
        excluded_content = <<~YAML
          methods:
            "app/models/user.rb":
              - excluded_method: "Called via metaprogramming"
        YAML
        File.write("excluded.yml", excluded_content)

        config = Keela::Configuration.new
        config.excluded_path = "excluded.yml"
        strategy = Keela::Strategies::Methods.new
        scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

        definitions = [
          { name: "excluded_method", file: "app/models/user.rb" },
          { name: "kept_method", file: "app/models/user.rb" }
        ]

        result = scanner.send(:filter_excluded, definitions)

        assert_equal 1, result.size
        assert_equal "kept_method", result.first[:name]
      end
    end
  end

  def test_filter_excluded_with_legacy_flat_format
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        # Legacy flat format: no strategy grouping
        excluded_content = <<~YAML
          "app/models/user.rb":
            - excluded_method: "Called via metaprogramming"
        YAML
        File.write("excluded.yml", excluded_content)

        config = Keela::Configuration.new
        config.excluded_path = "excluded.yml"
        strategy = Keela::Strategies::Methods.new
        scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

        definitions = [
          { name: "excluded_method", file: "app/models/user.rb" },
          { name: "kept_method", file: "app/models/user.rb" }
        ]

        result = scanner.send(:filter_excluded, definitions)

        assert_equal 1, result.size
        assert_equal "kept_method", result.first[:name]
      end
    end
  end

  def test_filter_excluded_strategy_aware_only_excludes_matching_strategy
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        # Same name excluded for scopes, but NOT for methods
        excluded_content = <<~YAML
          scopes:
            "app/models/user.rb":
              - active: "Used dynamically"
        YAML
        File.write("excluded.yml", excluded_content)

        config = Keela::Configuration.new
        config.excluded_path = "excluded.yml"

        # Methods strategy should NOT exclude 'active'
        methods_strategy = Keela::Strategies::Methods.new
        methods_scanner = Keela::Scanner.new(strategy: methods_strategy, configuration: config)

        definitions = [{ name: "active", file: "app/models/user.rb" }]
        result = methods_scanner.send(:filter_excluded, definitions)

        assert_equal 1, result.size, "Methods strategy should not exclude 'active' when only scopes has it excluded"

        # Scopes strategy SHOULD exclude 'active'
        scopes_strategy = Keela::Strategies::Scopes.new
        scopes_scanner = Keela::Scanner.new(strategy: scopes_strategy, configuration: config)

        result = scopes_scanner.send(:filter_excluded, definitions)

        assert_equal 0, result.size, "Scopes strategy should exclude 'active'"
      end
    end
  end

  def test_filter_excluded_strategy_aware_with_multiple_strategies
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        # Different exclusions for different strategies
        excluded_content = <<~YAML
          methods:
            "app/models/user.rb":
              - method_only: "Excluded for methods"
          scopes:
            "app/models/user.rb":
              - scope_only: "Excluded for scopes"
        YAML
        File.write("excluded.yml", excluded_content)

        config = Keela::Configuration.new
        config.excluded_path = "excluded.yml"

        definitions = [
          { name: "method_only", file: "app/models/user.rb" },
          { name: "scope_only", file: "app/models/user.rb" },
          { name: "neither", file: "app/models/user.rb" }
        ]

        # Methods strategy excludes method_only, keeps scope_only and neither
        methods_scanner = Keela::Scanner.new(
          strategy: Keela::Strategies::Methods.new,
          configuration: config
        )
        result = methods_scanner.send(:filter_excluded, definitions)
        names = result.map { |d| d[:name] }

        assert_equal 2, result.size
        assert_includes names, "scope_only"
        assert_includes names, "neither"
        refute_includes names, "method_only"

        # Scopes strategy excludes scope_only, keeps method_only and neither
        scopes_scanner = Keela::Scanner.new(
          strategy: Keela::Strategies::Scopes.new,
          configuration: config
        )
        result = scopes_scanner.send(:filter_excluded, definitions)
        names = result.map { |d| d[:name] }

        assert_equal 2, result.size
        assert_includes names, "method_only"
        assert_includes names, "neither"
        refute_includes names, "scope_only"
      end
    end
  end

  def test_filter_excluded_returns_all_definitions_when_no_exclusion_file
    config = Keela::Configuration.new
    # No excluded_path set, no default files exist
    scanner = Keela::Scanner.new(strategy: @strategy, configuration: config)

    definitions = [
      { name: "method_a", file: "app/models/user.rb" },
      { name: "method_b", file: "app/models/user.rb" }
    ]

    result = scanner.send(:filter_excluded, definitions)

    assert_equal 2, result.size
  end

  # resolve_baseline_path tests

  def test_resolve_baseline_path_returns_configured_path_when_file_exists
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        File.write("custom_baseline.yml", "---\n{}")

        config = Keela::Configuration.new
        config.baseline_path = "custom_baseline.yml"
        scanner = Keela::Scanner.new(strategy: @strategy, configuration: config)

        assert_equal "custom_baseline.yml", scanner.send(:resolve_baseline_path)
      end
    end
  end

  def test_resolve_baseline_path_returns_nil_when_configured_path_does_not_exist
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        config = Keela::Configuration.new
        config.baseline_path = "nonexistent.yml"
        scanner = Keela::Scanner.new(strategy: @strategy, configuration: config)

        assert_nil scanner.send(:resolve_baseline_path)
      end
    end
  end

  def test_resolve_baseline_path_prefers_keela_directory
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        Dir.mkdir(".keela")
        File.write(".keela/baseline.yml", "---\n{}")
        File.write("keela_baseline.yml", "---\n{}")

        config = Keela::Configuration.new
        scanner = Keela::Scanner.new(strategy: @strategy, configuration: config)

        assert_equal ".keela/baseline.yml", scanner.send(:resolve_baseline_path)
      end
    end
  end

  def test_resolve_baseline_path_falls_back_to_root_file
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        File.write("keela_baseline.yml", "---\n{}")

        config = Keela::Configuration.new
        scanner = Keela::Scanner.new(strategy: @strategy, configuration: config)

        assert_equal "keela_baseline.yml", scanner.send(:resolve_baseline_path)
      end
    end
  end

  def test_resolve_baseline_path_returns_nil_when_no_files_exist
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        config = Keela::Configuration.new
        scanner = Keela::Scanner.new(strategy: @strategy, configuration: config)

        assert_nil scanner.send(:resolve_baseline_path)
      end
    end
  end
end


