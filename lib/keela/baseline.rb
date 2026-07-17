# frozen_string_literal: true

require "yaml"

module Keela
  # Handles reading and writing baseline files with multiple strategy sections.
  #
  # File format:
  #   methods:
  #     app/models/user.rb:
  #       - unused_method
  #   scopes:
  #     app/models/user.rb:
  #       - unused_scope
  #
  class Baseline
    attr_reader :path

    def initialize(path)
      @path = path
      @data = nil
    end

    def exists?
      path && File.exist?(path)
    end

    def load
      return {} unless exists?

      @data = YAML.load_file(path) || {}
    end

    def data
      @data ||= load
    end

    def get(strategy_name)
      data[strategy_name] || {}
    end

    def set(strategy_name, unused_collection)
      # Ensure we've loaded existing data before setting
      load if @data.nil? && exists?
      @data ||= {}
      @data[strategy_name] = unused_collection.sort.to_h
    end

    def save
      return unless path

      header = <<~HEADER
        # Unused code identified by Keela.
        # These are potential targets for removal.
        #
        # If an item listed here is actually in use,
        # remove it from this file and add it to your excluded file.
        #
      HEADER

      sorted_data = data.sort.to_h
      yaml_content = if sorted_data.empty? || sorted_data.values.all?(&:empty?)
                       "#{header}---\n{}\n"
                     else
                       "#{header}#{format_yaml(sorted_data)}"
                     end

      File.write(path, yaml_content)
    end

    private

    def format_yaml(hash)
      indent_yaml_list_items(hash.to_yaml)
    end

    # Indents YAML list items that are not already indented.
    def indent_yaml_list_items(yaml_string)
      yaml_string.gsub(/\n-(\s+\S)/, "\n  -\\1")
    end
  end
end
