# frozen_string_literal: true

require_relative "lib/keela/version"

Gem::Specification.new do |s|
  s.name        = "keela"
  s.version     = Keela::VERSION
  s.summary     = "Sniff out unused code in your Ruby codebase"
  s.description = "Like the famous CSI dog who found what others missed, Keela detects unused methods and scopes in your Ruby codebase."
  s.authors     = ["Kerri Miller"]
  s.email       = "kerrizor@kerrizor.com"
  s.homepage    = "https://github.com/kerrizor/keela"
  s.license     = "MIT"

  s.required_ruby_version = ">= 3.1.0"

  s.files = Dir.glob(%w[
    lib/**/*.rb
    exe/*
    README.md
    LICENSE.txt
    CHANGELOG.md
  ])

  s.bindir      = "exe"
  s.executables = ["keela"]

  s.add_dependency "parallel", "~> 1.20"
  s.add_dependency "rainbow", "~> 3.0"
  s.add_dependency "ruby-progressbar", "~> 1.11"

  s.metadata = {
    "homepage_uri" => s.homepage,
    "source_code_uri" => "https://github.com/kerrizor/keela",
    "changelog_uri" => "https://github.com/kerrizor/keela/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "https://github.com/kerrizor/keela/issues"
  }
end
