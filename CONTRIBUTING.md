# Contributing to Keela

Thanks for your interest in contributing to Keela! This document covers how to get started.

## Development Setup

```bash
git clone https://github.com/kerrizor/keela.git
cd keela
bundle install
```

## Running Tests

```bash
bundle exec rake test
```

All tests must pass before submitting a PR.

## Code Style

- Use `frozen_string_literal: true` at the top of all Ruby files
- Follow standard Ruby conventions
- Keep methods small and focused
- Add tests for new functionality

## Adding a New Strategy

The main extension point is creating new detection strategies. Each strategy defines how to find definitions and detect their usage.

### 1. Create the Strategy Class

Create a new file in `lib/keela/strategies/`:

```ruby
# frozen_string_literal: true

module Keela
  module Strategies
    class MyStrategy < Strategy
      def name
        "my_strategy"  # Used in CLI: --type my_strategy
      end

      def definition_file_pattern
        # Regex to match files that may contain definitions
        %r{app/models}
      end

      def extract_definition(line)
        # Return the definition name if this line defines one, nil otherwise
        return nil unless line =~ /my_pattern\s+:(\w+)/

        Regexp.last_match(1)
      end

      def usage_regex(name)
        # Regex to detect usage of the given name
        /#{Regexp.quote(name)}\W/
      end

      def skip_comments?
        # Whether to skip lines starting with #
        true
      end
    end
  end
end
```

### 2. Register the Strategy

Add your strategy to `exe/keela`:

```ruby
STRATEGY_MAP = {
  # ... existing strategies ...
  my_strategy: Keela::Strategies::MyStrategy,
}.freeze
```

If it should be included in `--type all`, add it to `DEFAULT_STRATEGIES`:

```ruby
DEFAULT_STRATEGIES = %i[methods scopes constants delegations attributes my_strategy].freeze
```

### 3. Add Tests

Create `test/keela/strategies/my_strategy_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class MyStrategyTest < Minitest::Test
  def setup
    @strategy = Keela::Strategies::MyStrategy.new
  end

  def test_name
    assert_equal "my_strategy", @strategy.name
  end

  def test_extract_definition_matches_pattern
    line = "my_pattern :foo"
    assert_equal "foo", @strategy.extract_definition(line)
  end

  def test_extract_definition_returns_nil_for_non_match
    line = "something_else :bar"
    assert_nil @strategy.extract_definition(line)
  end

  def test_usage_regex_matches_usage
    regex = @strategy.usage_regex("foo")
    assert_match regex, "object.foo("
    assert_match regex, "foo "
  end
end
```

### 4. Update Documentation

- Add the strategy to the table in `README.md`
- Add a changelog entry under `[Unreleased]`

## Pull Request Process

1. **Branch naming**: Use `your-username/description` (e.g., `kerrizor/add-callbacks-strategy`)

2. **Changelog**: Add an entry to `CHANGELOG.md` under `[Unreleased]`:
   ```markdown
   ### Added
   - **New strategy** - Description of what it detects
   ```

3. **Tests**: Ensure all tests pass with `bundle exec rake test`

4. **PR description**: Explain what the change does and why

## Strategy Interface Reference

| Method | Required | Description |
|--------|----------|-------------|
| `name` | Yes | Human-readable name (used in CLI and output) |
| `definition_file_pattern` | Yes | Regex to match files that may contain definitions |
| `extract_definition(line)` | Yes | Extract definition name from a line, or `nil` |
| `usage_regex(name)` | Yes | Regex to detect usage of the given name |
| `skip_comments?` | No | Whether to skip `#` comment lines (default: `false`) |
| `extract_definitions_from_file(filepath, lines)` | No | Custom file parsing (e.g., for YAML). Return `nil` for default line-by-line parsing |

## Questions?

Open an issue if you have questions or want to discuss a feature before implementing it.
