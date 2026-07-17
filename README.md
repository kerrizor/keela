# Keela 🐕

**Your Ruby codebase's forensic investigator.**

Like her namesake — the famous springer spaniel who helped solve cases by finding microscopic traces that eluded forensic teams — Keela sniffs out the dead code that `grep` missed.

```
🔍 6 strategies: methods, scopes, constants, delegates, attrs, i18n
🎯 Baseline mode — only bark at NEW dead code  
📊 JSON output for CI pipelines
```

## Why Remove Unused Code?

Dead code isn't harmless — it's actively costly:

- **Cognitive overhead**: Developers read and try to understand code that doesn't matter, slowing down onboarding and feature work
- **CI minutes**: Tests for unused methods still run, burning compute time on every pipeline
- **False confidence**: Test coverage metrics include dead code, masking gaps in the code that actually runs
- **Refactoring friction**: Unused code creates dependencies that make refactoring harder ("wait, is this called somewhere?")
- **Security surface**: More code means more potential vulnerabilities, even in paths users never hit

Most codebases accumulate dead code gradually — a feature flag that's always on, a method replaced but never deleted, a scope that lost its last caller. Keela helps you find it and clean it up.

## Installation

```bash
gem install keela
```

Or add to your Gemfile:

```ruby
gem 'keela', group: :development
```

## Quick Start

```bash
# First time: generate a baseline of current unused code
keela --update-baseline

# This creates .keela_baseline.yml in your project root

# From now on, just run:
keela

# Keela will fail if:
#   - NEW unused code is detected (someone added dead code)
#   - Previously unused code was REMOVED (time to update the baseline!)
```

## How It Works

Keela operates in two modes:

### Baseline Mode (Default)

If a `.keela_baseline.yml` file exists, Keela compares the current scan against it:

| Scenario | Result |
|----------|--------|
| No changes from baseline | ✅ Pass (silent, exit 0) |
| NEW unused code detected | ❌ Fail (shows new items) |
| Code REMOVED from baseline | ❌ Fail (prompts to update baseline) |

This lets you gradually pay down tech debt while preventing new dead code from sneaking in.

### Report Mode

If no baseline exists (or you use `--report`), Keela shows all unused code:

```bash
keela --report
```

## Command Line Options

```bash
# Scan for all unused code (methods, scopes, constants, delegations, attributes)
keela

# Scan for specific types
keela --type methods
keela --type scopes

# Combine multiple types
keela --type methods,scopes,constants

# Force report mode (ignore baseline)
keela --report

# Update the baseline file
keela --update-baseline

# Use a custom baseline path
keela --baseline config/unused_baseline.yml

# Specify excluded items file
keela --excluded config/keela_excluded.yml

# Custom file extensions
keela --extensions rb,rake,haml

# Exclude files matching patterns
keela --exclude 'vendor/**/*' --exclude 'tmp/**/*'

# Include additional directories (adds to defaults)
keela --include 'engines/**/*.rb' --include 'custom/**/*.rb'

# Use a custom config file
keela --config path/to/keela.yml

# Output as JSON (for CI integrations)
keela --format json

# Show version
keela --version
```

## Detection Strategies

Keela detects several types of unused code:

| Strategy | Detects | Example |
|----------|---------|---------|
| **methods** | Unused method definitions | `def unused_method` |
| **scopes** | Unused ActiveRecord scopes | `scope :unused_scope, -> { }` |
| **constants** | Unused constants | `UNUSED_CONSTANT = 'value'` |
| **delegations** | Unused delegate declarations | `delegate :unused, to: :target` |
| **attributes** | Unused attr_* declarations | `attr_accessor :unused_attr` |
| **i18n_keys** | Unused translation keys | `en.users.unused_key` in locale YAML |

Run all strategies (default) or target specific ones with `--type`.

**Note:** The `i18n_keys` strategy is not included in `--type all` because it requires scanning YAML locale files. Run it explicitly with `--type i18n_keys`.

### I18n Keys (Beta)

The `i18n_keys` strategy is **beta** and may produce false positives. It cannot detect:

- **Lazy lookup** - `t('.title')` in views resolves based on the view path
- **Dynamic keys** - `t("users.#{action}.title")` with interpolated segments
- **Model translations** - `User.human_attribute_name(:email)` and `User.model_name.human`
- **Pluralization siblings** - If `one:` is used, `other:` may appear unused

Review results carefully and use the exclusion file for known false positives.

## Configuration File

Create a `keela.yml` or `.keela.yml` in your project root:

```yaml
# keela.yml
extensions:
  - rb
  - haml
  - erb

exclude_patterns:
  - "vendor/**/*"
  - "tmp/**/*"

include_patterns:
  - "engines/**/*.%<ext>s"

excluded_path: ".keela_excluded.yml"
baseline_path: ".keela_baseline.yml"
```

Keela automatically loads `keela.yml` or `.keela.yml` from the current directory. Use `--config` to specify a different path.

### Customizing Which Files to Scan

There are two approaches:

**1. Tweak the defaults** with `--include` and `--exclude` (or `include_patterns`/`exclude_patterns` in config):

```bash
# Add engines/ to the default app/, lib/, config/ directories
keela --include 'engines/**/*.rb'

# Exclude vendor files from scanning
keela --exclude 'vendor/**/*'
```

**2. Full control** with `directory_patterns` - replaces the defaults entirely:

```yaml
# keela.yml - scan ONLY these directories
directory_patterns:
  - "src/**/*.%<ext>s"
  - "custom/**/*.%<ext>s"
```

Use `directory_patterns` when you need complete control. Use `--include`/`--exclude` when you just want to tweak the defaults.

**Note:** Mixing both approaches raises a `ConfigurationError`. Choose one or the other.

**Available options:**

| Key | Description | Default |
|-----|-------------|---------|
| `directory_patterns` | Glob patterns for files to scan (replaces defaults) | `app/`, `lib/`, `config/` |
| `extensions` | File extensions to scan | `rb`, `haml`, `erb` |
| `include_patterns` | Additional patterns to scan (added to defaults) | `[]` |
| `exclude_patterns` | Patterns for files to exclude | `[]` |
| `excluded_path` | Path to YAML file of excluded items | `nil` |
| `baseline_path` | Path to baseline YAML file | `.keela_baseline.yml` |
| `required_directory` | Directory that must exist for scanning to proceed | `nil` |

## CI Integration

Keela is designed for CI pipelines. Add it to catch dead code before it merges:

```yaml
# .gitlab-ci.yml
unused_code:
  script:
    - bundle exec keela
  rules:
    - if: $CI_MERGE_REQUEST_IID
```

```yaml
# .github/workflows/ci.yml
- name: Check for unused code
  run: bundle exec keela
```

The workflow:

1. **Initial setup**: Run `keela --update-baseline` and commit `.keela_baseline.yml`
2. **CI runs**: `keela` compares against baseline, fails on new dead code
3. **After cleanup**: Run `keela --update-baseline` to update the baseline

### JSON Output

Use `--format json` for machine-readable output:

```bash
keela --format json --report
```

```json
{
  "strategies": ["methods", "scopes"],
  "unused": {
    "methods": {
      "app/models/user.rb": ["unused_method", "old_helper"]
    },
    "scopes": {
      "app/models/post.rb": ["inactive"]
    }
  },
  "summary": {
    "total": 3,
    "by_strategy": {
      "methods": 2,
      "scopes": 1
    }
  }
}
```

This is useful for integrating with other tools, generating reports, or processing results programmatically.

## Exclusion File

Some code appears unused but is actually called dynamically. Exclude it:

```yaml
# .keela_excluded.yml
app/models/user.rb:
  - legacy_method: "Called via metaprogramming"
  - callback_method: "Used as ActiveRecord callback"
app/helpers/application_helper.rb:
  - helper_method: "Called from views dynamically"
```

Then run with:

```bash
keela --excluded .keela_excluded.yml
```

## Ruby API

```ruby
require 'keela'

# Configure Keela
Keela.configure do |config|
  config.extensions = %w[rb haml erb]
  config.directory_patterns = %w[
    app/**/*.%<ext>s
    lib/**/*.%<ext>s
  ]
  config.include_patterns = %w[engines/**/*.%<ext>s]
  config.exclude_patterns = %w[vendor/**/* tmp/**/*]
  config.excluded_path = '.keela_excluded.yml'
  config.baseline_path = '.keela_baseline.yml'
end

# Run a scan
strategy = Keela::Strategies::Methods.new
scanner = Keela::Scanner.new(strategy: strategy)
success = scanner.run

# Access results
scanner.unused_collection  # Hash of file => [unused_names]
scanner.new_unused         # Items not in baseline
scanner.removed            # Items in baseline but no longer unused
```

## Custom Strategies

Detect other patterns by creating your own strategy:

```ruby
class CallbackStrategy < Keela::Strategy
  def name
    "callbacks"
  end

  def definition_file_pattern
    %r{app/models}
  end

  def extract_definition(line)
    # Match: before_save :do_something
    line =~ /(?:before|after|around)_\w+\s+:(\w+)/ ? Regexp.last_match(1) : nil
  end

  def usage_regex(name)
    /def #{Regexp.quote(name)}\b/
  end

  def skip_comments?
    true
  end
end

scanner = Keela::Scanner.new(strategy: CallbackStrategy.new)
scanner.run(force_report: true)
```

## About the Name

Keela was a famous English Springer Spaniel known as the "CSI dog." She could detect microscopic traces of blood that other forensic methods missed, helping solve cases that had gone cold for decades. Her nose was so sensitive she found evidence that luminol and DNA testing couldn't.

Like her namesake, this gem finds the dead code that `grep` and your IDE missed.

*Good girl, Keela.* 🦴

## License

MIT License. See [LICENSE.txt](LICENSE.txt).
