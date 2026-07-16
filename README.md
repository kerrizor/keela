# Keela 🐕

Like the famous CSI dog who found what others missed, Keela sniffs out unused code in your Ruby codebase.

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
# Scan for all unused code (methods and scopes)
keela

# Scan for specific types
keela --type methods
keela --type scopes

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

# Show version
keela --version
```

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

[Keela](https://en.wikipedia.org/wiki/Keela_(dog)) was a famous English Springer Spaniel known as the "CSI dog." She could detect microscopic traces of blood that other methods missed, and worked on many high-profile forensic cases including the Madeleine McCann investigation. Like her namesake, this gem finds the unused code that other tools miss.

## License

MIT License. See [LICENSE.txt](LICENSE.txt).
