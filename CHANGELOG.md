# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Unused entries are no longer listed more than once per file in reports and baselines when a single definition is extracted from multiple lines (e.g. the same method delegated twice, or a constant declared and referenced)

## [0.4.1] - 2026-08-21

### Fixed

- Constants used as hash keys (`CONST => value`) or in rescue splats (`rescue *ERRORS => e`) are now correctly detected as used ([#63](https://github.com/kerrizor/keela/pull/63))
- Methods referenced as literal symbols (`:method_name`) are now detected as used, including Rails callbacks, `send(:method)`, `validate :method`, etc. ([#64](https://github.com/kerrizor/keela/issues/64))
- I18n pluralization keys (`one`, `other`, `zero`, etc.) are now detected as used when the parent key is called with `t('key', count: n)` ([#69](https://github.com/kerrizor/keela/pull/69))
- I18n lazy lookup (`t('.title')` in views) now correctly resolves to the full key based on the view path ([#17](https://github.com/kerrizor/keela/issues/17))

## [0.4.0] - 2026-08-14

### Added

- **Verbose mode** via `--verbose` flag to show files being scanned, glob patterns, and configuration for debugging ([#53](https://github.com/kerrizor/keela/pull/53))
- **Source location** via `--source-location` flag to show line numbers in reports for easier navigation ([#55](https://github.com/kerrizor/keela/pull/55))
- **Exclusion validation** via `--test-exclusions` flag to find stale entries in exclusion files ([#56](https://github.com/kerrizor/keela/pull/56))
- **TOON output format** via `--format toon` for token-efficient LLM-friendly output ([#58](https://github.com/kerrizor/keela/pull/58))
- **Configurable definition paths** per strategy via `strategies.<name>.definition_paths` in config file ([#59](https://github.com/kerrizor/keela/pull/59))

### Changed

- **`--quiet` now suppresses all output**, not just the progress bar. Use exit code for success/failure in scripts. ([#54](https://github.com/kerrizor/keela/pull/54))

### Fixed

- Multi-method delegate declarations now detect all methods, not just the first ([#51](https://github.com/kerrizor/keela/pull/51))
- Class methods (`def self.foo`) are now correctly detected as unused ([#60](https://github.com/kerrizor/keela/pull/60))

## [0.3.0] - 2026-08-05

### Added

- **Strategy-aware exclusion file format** - Exclusion files can now be organized by strategy (methods, scopes, etc.) to match the baseline file format. This allows excluding the same name in one strategy while flagging it in another. The legacy flat format is still supported for backward compatibility. ([#35](https://github.com/kerrizor/keela/pull/35))

### Changed

- **Performance: Share source files across strategies** - When scanning multiple strategies, source files are now loaded once and shared, reducing scan time by ~33% on large codebases. ([#37](https://github.com/kerrizor/keela/pull/37))

### Fixed

- CLI options now correctly override config file settings ([#36](https://github.com/kerrizor/keela/pull/36))

## [0.2.3] - 2026-07-31

### Fixed

- Constants strategy no longer detects regex match operator (`=~`) usage as constant definitions ([#31](https://github.com/kerrizor/keela/pull/31))

### Changed

- Stop tracking `Gemfile.lock` - gems should not commit their lockfile ([#33](https://github.com/kerrizor/keela/pull/33))

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
