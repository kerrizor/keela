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
    config.directory_patterns = %w[app/**/*.%<ext>s]
    config.include_patterns = %w[engines/**/*.%<ext>s]

    strategy = Keela::Strategies::Methods.new
    scanner = Keela::Scanner.new(strategy: strategy, configuration: config)

    globs = scanner.file_globs

    assert_includes globs, "app/**/*.rb"
    assert_includes globs, "engines/**/*.rb"
  end
end


