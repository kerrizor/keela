# frozen_string_literal: true

require "yaml"
require "rainbow"

module Keela
  # Rewrites an exclusion file in sorted, normalized order.
  #
  # Reorder-only and non-destructive: it never prunes stale entries, it only
  # deep-sorts the existing data and re-dumps it with a fixed header. Freeform
  # YAML comments are not preserved (Psych drops them on load).
  #
  class ExclusionNormalizer
    STRATEGY_MAP = {
      methods: Strategies::Methods,
      scopes: Strategies::Scopes,
      constants: Strategies::Constants,
      delegations: Strategies::Delegations,
      attributes: Strategies::Attributes,
      i18n_keys: Strategies::I18nKeys
    }.freeze

    attr_reader :excluded_path

    def initialize(excluded_path)
      @excluded_path = excluded_path
    end

    def normalize
      unless File.exist?(excluded_path)
        puts Rainbow("Exclusion file not found: #{excluded_path}").red
        return false
      end

      data = YAML.load_file(excluded_path, symbolize_names: true) || {}

      sorted = strategy_aware_format?(data) ? deep_sort_strategy_aware(data) : deep_sort_flat(data)

      File.write(excluded_path, serialize(sorted))
      puts Rainbow("Normalized #{excluded_path}").green.bright
      true
    end

    private

    def strategy_aware_format?(data)
      data.keys.any? { |k| STRATEGY_MAP.key?(k) }
    end

    def deep_sort_strategy_aware(data)
      data.sort_by { |key, _| key.to_s }.to_h do |strategy_name, files|
        [strategy_name.to_s, sort_files(files || {})]
      end
    end

    def deep_sort_flat(data)
      sort_files(data)
    end

    def sort_files(files)
      files.sort_by { |key, _| key.to_s }.to_h do |file_path, entries|
        [file_path.to_s, sort_entries(entries || [])]
      end
    end

    # Sorts the name:reason entry array by name, converting the symbolized
    # key back to a string so the dumped YAML uses string keys.
    #
    def sort_entries(entries)
      entries
        .map { |entry| { entry.keys.first.to_s => entry.values.first } }
        .sort_by { |entry| entry.keys.first }
    end

    def serialize(data)
      if data.empty? || data.values.all? { |v| v.respond_to?(:empty?) && v.empty? }
        "#{header}---\n{}\n"
      else
        "#{header}#{format_yaml(data)}"
      end
    end

    def header
      <<~HEADER
        # Excluded items that Keela should not flag as unused.
        # These are known to be in use (e.g. called via metaprogramming).
        #
        # This file is normalized by `keela --normalize-exclusions`.
        # Freeform comments are not preserved when it is rewritten.
        #
      HEADER
    end

    def format_yaml(hash)
      indent_yaml_list_items(hash.to_yaml)
    end

    # Indents YAML list items that are not already indented, matching the
    # style Baseline uses for its output.
    #
    def indent_yaml_list_items(yaml_string)
      yaml_string.gsub(/\n-(\s+\S)/, "\n  -\\1")
    end
  end
end
