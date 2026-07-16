# frozen_string_literal: true

require "parallel"
require "yaml"

module Keela
  class Scanner
    attr_reader :strategy, :configuration, :source_files, :unused_collection, :new_unused, :removed

    def initialize(strategy:, configuration: Keela.configuration)
      @strategy = strategy
      @configuration = configuration
      @source_files = {}
      @unused_collection = Hash.new { |hash, key| hash[key] = [] }
      @new_unused = []
      @removed = []
    end

    def run(force_report: false, update_baseline: false)
      return true unless should_run?

      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      load_source_files
      definitions = find_definitions
      definitions = filter_excluded(definitions)

      # Determine mode: report if forced, updating baseline, or no baseline exists
      report_mode = force_report || update_baseline || !baseline_exists?

      find_unused(definitions, show_progress: report_mode)

      if report_mode
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
        reporter.print_full_report(unused_collection, elapsed)
        write_baseline_file if update_baseline
        return true
      end

      # Baseline mode: compare against known unused code
      compare_with_baseline
      reporter.print_diff_report(
        new_unused,
        removed,
        excluded_path: configuration.excluded_path || "excluded.yml",
        baseline_path: configuration.baseline_path
      )

      new_unused.empty? && removed.empty?
    end

    def file_globs
      configuration.extensions.flat_map do |ext|
        configuration.directory_patterns.map { |pattern| format(pattern, ext: ext) }
      end
    end

    private

    def baseline_exists?
      configuration.baseline_path && File.exist?(configuration.baseline_path)
    end

    def should_run?
      return true unless configuration.required_directory

      Dir.exist?(configuration.required_directory)
    end

    def reporter
      @reporter ||= Reporter.new(strategy.name)
    end

    def load_source_files
      Dir.glob(file_globs).each do |filename|
        @source_files[filename] = File.readlines(filename)
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
      baseline = YAML.load_file(configuration.baseline_path) || {}
      baseline_items = baseline.flat_map { |f, names| [f].product(names) }

      current_items = unused_collection.flat_map { |f, names| [f].product(names) }

      @new_unused = current_items - baseline_items
      @removed = baseline_items - current_items
    end

    def write_baseline_file
      return unless configuration.baseline_path

      header = <<~HEADER
        # The #{strategy.name} listed here have been identified as "unused" by Keela,
        # and are potential targets for future removal.
        #
        # If a #{strategy.name.chomp('s')} listed here is actually in use,
        # remove it from this file and add it to your excluded file.
        #
      HEADER

      yaml_content = if unused_collection.empty?
                       "#{header}---\n{}\n"
                     else
                       sorted_collection = unused_collection.sort.to_h
                       "#{header}#{reporter.format_yaml(sorted_collection)}"
                     end

      File.write(configuration.baseline_path, yaml_content)
      puts Rainbow("Updated #{configuration.baseline_path}").green.bright
    end
  end
end
