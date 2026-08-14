# frozen_string_literal: true

require "yaml"
require "rainbow"

module Keela
  class ExclusionValidator
    STRATEGY_MAP = {
      methods: Strategies::Methods,
      scopes: Strategies::Scopes,
      constants: Strategies::Constants,
      delegations: Strategies::Delegations,
      attributes: Strategies::Attributes,
      i18n_keys: Strategies::I18nKeys
    }.freeze

    attr_reader :excluded_path, :results

    def initialize(excluded_path)
      @excluded_path = excluded_path
      @results = { valid: [], stale: [] }
    end

    def validate
      unless File.exist?(excluded_path)
        puts Rainbow("Exclusion file not found: #{excluded_path}").red
        return false
      end

      all_excluded = YAML.load_file(excluded_path, symbolize_names: true) || {}

      if all_excluded.empty?
        puts Rainbow("Exclusion file is empty: #{excluded_path}").yellow
        return true
      end

      puts "Validating exclusions in #{excluded_path}...\n\n"

      # Detect format: strategy-aware or legacy flat
      if strategy_aware_format?(all_excluded)
        validate_strategy_aware(all_excluded)
      else
        validate_legacy_flat(all_excluded)
      end

      print_results
      results[:stale].empty?
    end

    private

    def strategy_aware_format?(data)
      data.keys.any? { |k| STRATEGY_MAP.key?(k) }
    end

    def validate_strategy_aware(all_excluded)
      all_excluded.each do |strategy_name, files|
        next unless STRATEGY_MAP.key?(strategy_name)

        strategy = STRATEGY_MAP[strategy_name].new
        validate_files(strategy, strategy_name, files || {})
      end
    end

    def validate_legacy_flat(all_excluded)
      # Legacy format applies to all strategies, but we'll check against methods
      strategy = Strategies::Methods.new
      validate_files(strategy, :methods, all_excluded)
    end

    def validate_files(strategy, strategy_name, files)
      files.each do |file_path, entries|
        file_str = file_path.to_s
        entries ||= []

        entries.each do |entry|
          name = entry.keys.first.to_s
          reason = entry.values.first

          if !File.exist?(file_str)
            results[:stale] << {
              strategy: strategy_name,
              file: file_str,
              name: name,
              reason: reason,
              error: "file not found"
            }
          elsif !definition_exists?(strategy, file_str, name)
            results[:stale] << {
              strategy: strategy_name,
              file: file_str,
              name: name,
              reason: reason,
              error: "no definition found"
            }
          else
            results[:valid] << {
              strategy: strategy_name,
              file: file_str,
              name: name,
              reason: reason
            }
          end
        end
      end
    end

    def definition_exists?(strategy, file_path, name)
      return false unless File.exist?(file_path)

      lines = File.readlines(file_path)

      # Check custom extraction first (for I18n YAML files)
      custom_defs = strategy.extract_definitions_from_file(file_path, lines)
      if custom_defs
        return custom_defs.any? { |d| d[:name] == name }
      end

      # Default line-by-line extraction
      lines.any? do |line|
        next if strategy.skip_comments? && line.strip.start_with?("#")

        result = strategy.extract_definition(line)
        Array(result).compact.include?(name)
      end
    end

    def print_results
      if results[:valid].any?
        puts Rainbow("✅ Valid exclusions (#{results[:valid].size}):").green.bright
        group_by_strategy(results[:valid]).each do |strategy, entries|
          puts "   #{strategy}:"
          entries.each do |e|
            puts "     #{e[:file]}:#{e[:name]}"
          end
        end
        puts
      end

      if results[:stale].any?
        puts Rainbow("⚠️  Stale exclusions found (#{results[:stale].size}):").yellow.bright
        puts
        group_by_strategy(results[:stale]).each do |strategy, entries|
          puts "   #{strategy}:"
          entries.each do |e|
            puts "     #{e[:file]}:#{e[:name]} — #{e[:error]}"
          end
        end
        puts
        puts "Consider removing stale exclusions from #{excluded_path}"
      else
        puts Rainbow("All exclusions are valid!").green.bright
      end
    end

    def group_by_strategy(entries)
      entries.group_by { |e| e[:strategy] }
    end
  end
end
