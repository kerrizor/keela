# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "keela"
require "minitest/autorun"

# Helpers for strategies that override Strategy#used? with a faster formulation
# of Strategy#usage_regex.
#
# Such an override is only valid if it decides exactly what matching
# #usage_regex against the raw source decides, so these assert both answers at
# once. A regression that changes both consistently is still caught, because the
# expected answer is stated explicitly.
#
module UsageEquivalence
  def assert_used(name, source, strategy: @strategy)
    assert_usage(true, name, source, strategy: strategy)
  end

  def refute_used(name, source, strategy: @strategy)
    assert_usage(false, name, source, strategy: strategy)
  end

  def assert_usage(expected, name, source, strategy: @strategy)
    source = Keela::Source.new(source)
    strategy.prepare(source)

    where = "#{name.inspect} in #{source.inspect}"

    assert_equal expected, strategy.usage_regex(name).match?(source.text),
      "usage_regex decided the opposite for #{where}"
    assert_equal expected, strategy.used?(name, source),
      "used? decided the opposite for #{where}"
  end

  # Asserts the two agree without stating which answer is right. For inputs
  # where the exact answer is incidental and only the equivalence matters.
  def assert_equivalent(name, source, strategy: @strategy)
    source = Keela::Source.new(source)
    strategy.prepare(source)

    assert_equal strategy.usage_regex(name).match?(source.text),
      strategy.used?(name, source),
      "used? and usage_regex disagreed for #{name.inspect} in #{source.inspect}"
  end
end
