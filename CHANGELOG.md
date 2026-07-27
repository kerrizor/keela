# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.2] - 2026-07-27

### Changed

- Config file lookup now includes `.keela/config.yml` as the first option ([#30](https://github.com/kerrizor/keela/pull/30))
  - Lookup order: `.keela/config.yml` → `keela.yml` → `.keela.yml`

## [0.2.1] - 2026-07-27

### Added

- **Quiet mode** via `--quiet` / `-q` CLI flag to suppress progress bar output ([#26](https://github.com/kerrizor/keela/issues/26))

### Changed

- Default suggested excluded filename changed from `excluded.yml` to `keela_excluded.yml` for consistency with `keela_baseline.yml` ([#28](https://github.com/kerrizor/keela/pull/28))
- Default file locations now support `.keela/` directory with fallback to root ([#29](https://github.com/kerrizor/keela/pull/29))
  - Excluded: `.keela/excluded.yml` → `keela_excluded.yml`
  - Baseline: `.keela/baseline.yml` → `keela_baseline.yml`

## [0.2.0] - 2026-07-17

### Added

- `Baseline` class for managing multi-strategy baseline files ([#1](https://github.com/kerrizor/keela/pull/1))
- Single baseline file now supports multiple strategy sections (methods, scopes)
- **Constants strategy** for detecting unused constant definitions ([#2](https://github.com/kerrizor/keela/pull/2))
- **Delegations strategy** for detecting unused `delegate :method, to: :target` declarations ([#4](https://github.com/kerrizor/keela/pull/4))
- **Attributes strategy** for detecting unused `attr_accessor`, `attr_reader`, `attr_writer` declarations ([#5](https://github.com/kerrizor/keela/pull/5))
- **Config file support** (`keela.yml` or `.keela.yml`) for project-specific settings ([#11](https://github.com/kerrizor/keela/pull/11))
- **Exclude patterns** via `--exclude` CLI flag or `exclude_patterns` in config file ([#12](https://github.com/kerrizor/keela/pull/12))
- **Include patterns** via `--include` CLI flag or `include_patterns` in config file ([#14](https://github.com/kerrizor/keela/pull/14))
- **Configuration validation** - raises `ConfigurationError` if `directory_patterns` is customized while also using `include_patterns` or `exclude_patterns` ([#15](https://github.com/kerrizor/keela/pull/15))
- **I18n keys strategy (beta)** for detecting unused translation keys in locale files ([#16](https://github.com/kerrizor/keela/pull/16))
- **Multiple types** can now be specified with `--type methods,scopes,constants` ([#18](https://github.com/kerrizor/keela/pull/18))
- **JSON output** via `--format json` for machine-readable results ([#19](https://github.com/kerrizor/keela/pull/19))

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
