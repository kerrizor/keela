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


