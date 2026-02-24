# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentCumulativeUsage < ActiveSupport::TestCase
  setup do
    @usage = ClaudeAgent::CumulativeUsage.new
  end

  # --- Initial State ---

  test "initial values are zero" do
    assert_equal 0, @usage.input_tokens
    assert_equal 0, @usage.output_tokens
    assert_equal 0, @usage.cache_read_input_tokens
    assert_equal 0, @usage.cache_creation_input_tokens
    assert_equal 0.0, @usage.total_cost_usd
    assert_equal 0, @usage.num_turns
    assert_equal 0, @usage.duration_ms
    assert_equal 0, @usage.duration_api_ms
  end

  test "initial to_h" do
    expected = {
      input_tokens: 0,
      output_tokens: 0,
      cache_read_input_tokens: 0,
      cache_creation_input_tokens: 0,
      total_cost_usd: 0.0,
      num_turns: 0,
      duration_ms: 0,
      duration_api_ms: 0
    }
    assert_equal expected, @usage.to_h
  end

  # --- Single Turn ---

  test "track single result message" do
    result = make_result(
      usage: { input_tokens: 100, output_tokens: 50 },
      total_cost_usd: 0.01,
      num_turns: 1,
      duration_ms: 1000,
      duration_api_ms: 800
    )

    @usage.track(result)

    assert_equal 100, @usage.input_tokens
    assert_equal 50, @usage.output_tokens
    assert_equal 0.01, @usage.total_cost_usd
    assert_equal 1, @usage.num_turns
    assert_equal 1000, @usage.duration_ms
    assert_equal 800, @usage.duration_api_ms
  end

  test "track result with cache tokens" do
    result = make_result(
      usage: {
        input_tokens: 200,
        output_tokens: 100,
        cache_read_input_tokens: 50,
        cache_creation_input_tokens: 25
      },
      total_cost_usd: 0.02,
      num_turns: 1
    )

    @usage.track(result)

    assert_equal 200, @usage.input_tokens
    assert_equal 100, @usage.output_tokens
    assert_equal 50, @usage.cache_read_input_tokens
    assert_equal 25, @usage.cache_creation_input_tokens
  end

  # --- Multiple Turns ---

  test "accumulates tokens across turns" do
    @usage.track(make_result(
      usage: { input_tokens: 100, output_tokens: 50 },
      total_cost_usd: 0.01,
      num_turns: 1,
      duration_ms: 1000,
      duration_api_ms: 800
    ))

    @usage.track(make_result(
      usage: { input_tokens: 200, output_tokens: 100 },
      total_cost_usd: 0.03,
      num_turns: 2,
      duration_ms: 1500,
      duration_api_ms: 1200
    ))

    assert_equal 300, @usage.input_tokens
    assert_equal 150, @usage.output_tokens
    assert_equal 0.03, @usage.total_cost_usd
    assert_equal 2, @usage.num_turns
    assert_equal 2500, @usage.duration_ms
    assert_equal 2000, @usage.duration_api_ms
  end

  test "accumulates cache tokens across turns" do
    @usage.track(make_result(
      usage: { cache_read_input_tokens: 10, cache_creation_input_tokens: 5 }
    ))

    @usage.track(make_result(
      usage: { cache_read_input_tokens: 20, cache_creation_input_tokens: 15 }
    ))

    assert_equal 30, @usage.cache_read_input_tokens
    assert_equal 20, @usage.cache_creation_input_tokens
  end

  # --- Nil Handling ---

  test "handles nil usage gracefully" do
    result = make_result(usage: nil, total_cost_usd: 0.01, num_turns: 1)
    @usage.track(result)

    assert_equal 0, @usage.input_tokens
    assert_equal 0, @usage.output_tokens
    assert_equal 0.01, @usage.total_cost_usd
    assert_equal 1, @usage.num_turns
  end

  test "handles nil cost" do
    result = ClaudeAgent::ResultMessage.new(
      subtype: "success",
      duration_ms: 0,
      duration_api_ms: 0,
      is_error: false,
      num_turns: 1,
      session_id: "session-test",
      total_cost_usd: nil,
      usage: { input_tokens: 100 }
    )
    @usage.track(result)

    assert_equal 100, @usage.input_tokens
    assert_equal 0.0, @usage.total_cost_usd
  end

  test "handles partial usage hash" do
    result = make_result(usage: { input_tokens: 100 })
    @usage.track(result)

    assert_equal 100, @usage.input_tokens
    assert_equal 0, @usage.output_tokens
    assert_equal 0, @usage.cache_read_input_tokens
  end

  # --- Non-ResultMessage ---

  test "ignores non-result messages" do
    assistant = ClaudeAgent::AssistantMessage.new(
      content: [ ClaudeAgent::TextBlock.new(text: "Hello") ],
      model: "claude"
    )
    @usage.track(assistant)

    assert_equal 0, @usage.input_tokens
    assert_equal 0.0, @usage.total_cost_usd
  end

  test "ignores nil" do
    @usage.track(nil)

    assert_equal 0, @usage.input_tokens
  end

  # --- Reset ---

  test "reset clears all counters" do
    @usage.track(make_result(
      usage: { input_tokens: 100, output_tokens: 50 },
      total_cost_usd: 0.05,
      num_turns: 3,
      duration_ms: 2000,
      duration_api_ms: 1500
    ))

    @usage.reset!

    assert_equal 0, @usage.input_tokens
    assert_equal 0, @usage.output_tokens
    assert_equal 0, @usage.cache_read_input_tokens
    assert_equal 0, @usage.cache_creation_input_tokens
    assert_equal 0.0, @usage.total_cost_usd
    assert_equal 0, @usage.num_turns
    assert_equal 0, @usage.duration_ms
    assert_equal 0, @usage.duration_api_ms
  end

  test "tracks normally after reset" do
    @usage.track(make_result(
      usage: { input_tokens: 100 },
      total_cost_usd: 0.01
    ))
    @usage.reset!
    @usage.track(make_result(
      usage: { input_tokens: 200 },
      total_cost_usd: 0.02
    ))

    assert_equal 200, @usage.input_tokens
    assert_equal 0.02, @usage.total_cost_usd
  end

  # --- to_h ---

  test "to_h reflects accumulated state" do
    @usage.track(make_result(
      usage: {
        input_tokens: 500,
        output_tokens: 200,
        cache_read_input_tokens: 30,
        cache_creation_input_tokens: 10
      },
      total_cost_usd: 0.05,
      num_turns: 2,
      duration_ms: 3000,
      duration_api_ms: 2500
    ))

    expected = {
      input_tokens: 500,
      output_tokens: 200,
      cache_read_input_tokens: 30,
      cache_creation_input_tokens: 10,
      total_cost_usd: 0.05,
      num_turns: 2,
      duration_ms: 3000,
      duration_api_ms: 2500
    }
    assert_equal expected, @usage.to_h
  end

  private

  def make_result(usage: nil, total_cost_usd: nil, num_turns: 1, duration_ms: 0, duration_api_ms: 0)
    ClaudeAgent::ResultMessage.new(
      subtype: "success",
      duration_ms: duration_ms,
      duration_api_ms: duration_api_ms,
      is_error: false,
      num_turns: num_turns,
      session_id: "session-test",
      total_cost_usd: total_cost_usd,
      usage: usage
    )
  end
end
