# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = "keela"
  s.version     = "0.0.2"
  s.summary     = "Sniff out unused code in your Ruby codebase"
  s.description = "Like the famous CSI dog who found what others missed, Keela detects unused methods and scopes in your Ruby codebase."
  s.authors     = ["Kerri Miller"]
  s.email       = "kerrizor@kerrizor.com"
  s.homepage    = "https://github.com/kerrizor/keela"
  s.license     = "MIT"
  s.files       = ["lib/keela.rb"]
  s.required_ruby_version = ">= 3.1.0"
end
