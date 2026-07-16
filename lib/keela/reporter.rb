# frozen_string_literal: true

require "rainbow"
require "yaml"

module Keela
  class Reporter
    attr_reader :strategy_name

    def initialize(strategy_name)
      @strategy_name = strategy_name
    end

    def print_full_report(unused_collection, elapsed_time)
      unused_count = unused_collection.values.flatten.size

      if unused_count > 0
        puts "\nFound #{unused_count} unused #{strategy_name}:\n\n"
        puts format_yaml(unused_collection)
        puts "\n"
      else
        puts Rainbow("No unused #{strategy_name} were found.").green.bright
      end

      puts "Finished in #{elapsed_time.round(2)} seconds."
    end

    def print_diff_report(new_unused, removed, excluded_path:, baseline_path:)
      print_new_unused(new_unused, excluded_path) unless new_unused.empty?

      if new_unused.size + removed.size > 0
        puts Rainbow("~" * 80).white.bright
        puts "\n"
      end

      print_removed(removed, baseline_path) unless removed.empty?
    end

    def format_yaml(collection)
      indent_yaml_list_items(collection.sort.to_h.to_yaml)
    end

    private

    def print_new_unused(new_unused, excluded_path)
      error = <<~MESSAGE
        We have detected #{new_unused.size} newly unused #{strategy_name}.

        Please remove these #{strategy_name}, or if in use, add to #{excluded_path}.
      MESSAGE

      puts Rainbow(error).red.bright
      puts Rainbow(format_yaml(parse_diff(new_unused))).red.bright
    end

    def print_removed(removed, baseline_path)
      message = <<~MESSAGE
        It appears you have removed unused #{strategy_name}. Thank you!

        Please update #{File.basename(baseline_path)} and remove entries for these #{strategy_name}.
      MESSAGE

      puts Rainbow(message).yellow.bright
      puts Rainbow(format_yaml(parse_diff(removed))).yellow.bright
    end

    def parse_diff(diff_to_parse)
      result = Hash.new { |hash, key| hash[key] = [] }

      diff_to_parse.each do |file_name, name|
        result[file_name] << name
      end

      result
    end

    # Indents YAML list items that are not already indented.
    # Ruby's to_yaml outputs list items without indentation (e.g., "- item"),
    # but we want 2-space indentation (e.g., "  - item").
    def indent_yaml_list_items(yaml_string)
      yaml_string.gsub(/\n-(\s+\S)/, "\n  -\\1")
    end
  end
end
