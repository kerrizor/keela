# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `Baseline` class for managing multi-strategy baseline files ([#1](https://github.com/kerrizor/keela/pull/1))
- Single baseline file now supports multiple strategy sections (methods, scopes)
- **Constants strategy** for detecting unused constant definitions (`SCREAMING_SNAKE_CASE = value`)
- **Delegations strategy** for detecting unused `delegate :method, to: :target` declarations

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
