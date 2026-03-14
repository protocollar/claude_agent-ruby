# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentMessagesResult < ActiveSupport::TestCase
  test "result_message_success" do
    msg = ClaudeAgent::ResultMessage.new(
      subtype: "success",
      duration_ms: 1500,
      duration_api_ms: 1200,
      is_error: false,
      num_turns: 3,
      session_id: "session-abc",
      total_cost_usd: 0.05,
      usage: { input_tokens: 100, output_tokens: 50 }
    )
    assert_equal "success", msg.subtype
    assert_equal 1500, msg.duration_ms
    assert_equal 1200, msg.duration_api_ms
    refute msg.error?
    assert msg.success?
    assert_equal 3, msg.num_turns
    assert_equal "session-abc", msg.session_id
    assert_equal 0.05, msg.total_cost_usd
    assert_equal({ input_tokens: 100, output_tokens: 50 }, msg.usage)
    assert_equal :result, msg.type
  end

  test "result_message_error" do
    msg = ClaudeAgent::ResultMessage.new(
      subtype: "error",
      duration_ms: 500,
      duration_api_ms: 400,
      is_error: true,
      num_turns: 1,
      session_id: "session-xyz"
    )
    assert msg.error?
    refute msg.success?
  end

  test "result_message_with_stop_reason" do
    msg = ClaudeAgent::ResultMessage.new(
      subtype: "success",
      duration_ms: 1500,
      duration_api_ms: 1200,
      is_error: false,
      num_turns: 3,
      session_id: "session-abc",
      stop_reason: "end_turn"
    )
    assert_equal "end_turn", msg.stop_reason
  end

  test "result_message_stop_reason_default_nil" do
    msg = ClaudeAgent::ResultMessage.new(
      subtype: "success",
      duration_ms: 1500,
      duration_api_ms: 1200,
      is_error: false,
      num_turns: 3,
      session_id: "session-abc"
    )
    assert_nil msg.stop_reason
  end

  test "result_message_with_fast_mode_state" do
    msg = ClaudeAgent::ResultMessage.new(
      subtype: "success",
      duration_ms: 1500,
      duration_api_ms: 1200,
      is_error: false,
      num_turns: 3,
      session_id: "session-abc",
      fast_mode_state: "enabled"
    )
    assert_equal "enabled", msg.fast_mode_state
  end

  test "result_message_fast_mode_state_default_nil" do
    msg = ClaudeAgent::ResultMessage.new(
      subtype: "success",
      duration_ms: 1500,
      duration_api_ms: 1200,
      is_error: false,
      num_turns: 3,
      session_id: "session-abc"
    )
    assert_nil msg.fast_mode_state
  end
end
