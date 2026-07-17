# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-07-17

### Added

- `Baseline` class for managing multi-strategy baseline files ([#1](https://github.com/kerrizor/keela/pull/1))
- Single baseline file now supports multiple strategy sections (methods, scopes)
- **Constants strategy** for detecting unused constant definitions (`SCREAMING_SNAKE_CASE = value`)
- **Delegations strategy** for detecting unused `delegate :method, to: :target` declarations
- **Attributes strategy** for detecting unused `attr_accessor`, `attr_reader`, `attr_writer` declarations
- **Config file support** (`keela.yml` or `.keela.yml`) for project-specific settings
- **Exclude patterns** via `--exclude` CLI flag or `exclude_patterns` in config file
- **Include patterns** via `--include` CLI flag or `include_patterns` in config file (adds to default directory patterns)
- **Configuration validation** - raises `ConfigurationError` if `directory_patterns` is customized while also using `include_patterns` or `exclude_patterns`
- **I18n keys strategy (beta)** for detecting unused translation keys in locale files (`--type i18n_keys`)
- **Multiple types** can now be specified with `--type methods,scopes,constants`
- **JSON output** via `--format json` for machine-readable results (useful for CI integrations)

### Fixed

- Running strategies separately no longer overwrites previous strategy data ([#1](https://github.com/kerrizor/keela/pull/1))

## [0.1.0] - 2026-07-16

### Added

- Initial release
- `Scanner` class for detecting unused code
- Built-in strategies for methods and scopes detection
- CLI tool with `--report` and `--update-baseline` modes
- Configurable file extensions and directory patterns
- Baseline comparison for CI integration
- Exclusion file support for false positives
