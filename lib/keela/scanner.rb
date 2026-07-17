# frozen_string_literal: true

require "parallel"
require "yaml"

module Keela
  class Scanner
    attr_reader :strategy, :configuration, :baseline, :source_files, :unused_collection, :new_unused, :removed

    def initialize(strategy:, configuration: Keela.configuration, baseline: nil)
      @strategy = strategy
      @configuration = configuration
      @baseline = baseline || Baseline.new(configuration.baseline_path)
      @source_files = {}
      @unused_collection = Hash.new { |hash, key| hash[key] = [] }
      @new_unused = []
      @removed = []
    end

    def run(force_report: false, update_baseline: false)
      return true unless should_run?

      validate_configuration!

      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      load_source_files
      definitions = find_definitions
      definitions = filter_excluded(definitions)

      # Determine mode: report if forced, updating baseline, or no baseline exists
      report_mode = force_report || update_baseline || !baseline.exists?

      find_unused(definitions, show_progress: report_mode)

      if report_mode
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
        reporter.print_full_report(unused_collection, elapsed)
        if update_baseline
          baseline.set(strategy.name, unused_collection)
          # Note: caller is responsible for calling baseline.save after all strategies run
        end
        return true
      end

      # Baseline mode: compare against known unused code
      compare_with_baseline
      reporter.print_diff_report(
        new_unused,
        removed,
        excluded_path: configuration.excluded_path || "excluded.yml",
        baseline_path: baseline.path
      )

      new_unused.empty? && removed.empty?
    end

    def file_globs
      all_patterns = configuration.directory_patterns + configuration.include_patterns

      configuration.extensions.flat_map do |ext|
        all_patterns.map { |pattern| format(pattern, ext: ext) }
      end
    end

    private

    def should_run?
      return true unless configuration.required_directory

      Dir.exist?(configuration.required_directory)
    end

    def validate_configuration!
      custom_directory_patterns = configuration.directory_patterns != default_directory_patterns
      has_include_patterns = !configuration.include_patterns.empty?
      has_exclude_patterns = !configuration.exclude_patterns.empty?

      return unless custom_directory_patterns && (has_include_patterns || has_exclude_patterns)

      raise ConfigurationError,
        "Cannot use include_patterns or exclude_patterns with custom directory_patterns. " \
        "Use directory_patterns for full control, OR use include/exclude to tweak the defaults."
    end

    def default_directory_patterns
      Keela::Configuration.new.directory_patterns
    end

    def reporter
      @reporter ||= Reporter.new(strategy.name)
    end

    def load_source_files
      Dir.glob(file_globs).each do |filename|
        next if excluded_file?(filename)

        @source_files[filename] = File.readlines(filename)
      end
    end

    def excluded_file?(filename)
      return false if configuration.exclude_patterns.empty?

      configuration.exclude_patterns.any? do |pattern|
        File.fnmatch?(pattern, filename, File::FNM_PATHNAME | File::FNM_EXTGLOB)
      end
    end

    def find_definitions
      source_files.keys.grep(strategy.definition_file_pattern).flat_map do |filename|
        source_files[filename].flat_map do |line|
          next [] if strategy.skip_comments? && line.strip.start_with?("#")

          name = strategy.extract_definition(line)
          name ? [{ name: name, file: filename }] : []
        end
      end
    end

    def filter_excluded(definitions)
      return definitions unless configuration.excluded_path
      return definitions unless File.exist?(configuration.excluded_path)

      excluded = YAML.load_file(configuration.excluded_path, symbolize_names: true) || {}

      definitions.reject do |h|
        excluded_for_file = excluded[h[:file].to_sym]
        excluded_for_file&.flat_map(&:keys)&.include?(h[:name].to_sym)
      end
    end

    def find_unused(definitions, show_progress: false)
      source_code = source_files.values.flatten.join

      progress_label = show_progress ? "Checking #{strategy.name}" : nil

      unused = Parallel.flat_map(definitions, progress: progress_label) do |definition|
        regex = strategy.usage_regex(definition[:name])
        regex.match?(source_code) ? [] : definition
      end

      unused.each do |unused_def|
        @unused_collection[unused_def[:file]] << unused_def[:name]
      end
    end

    def compare_with_baseline
      baseline_for_strategy = baseline.get(strategy.name)
      baseline_items = baseline_for_strategy.flat_map { |f, names| [f].product(names) }

      current_items = unused_collection.flat_map { |f, names| [f].product(names) }

      @new_unused = current_items - baseline_items
      @removed = baseline_items - current_items
    end
  end
end
