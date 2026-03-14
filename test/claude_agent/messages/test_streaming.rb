# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentMessagesStreaming < ActiveSupport::TestCase
  test "stream_event" do
    event = ClaudeAgent::StreamEvent.new(
      uuid: "evt-123",
      session_id: "session-abc",
      event: { type: "content_block_delta", delta: { text: "Hi" } }
    )
    assert_equal "evt-123", event.uuid
    assert_equal "session-abc", event.session_id
    assert_equal "content_block_delta", event.event_type
    assert_equal :stream_event, event.type
  end

  test "rate_limit_event" do
    info = {
      status: "allowed_warning",
      resetsAt: 1700000000,
      rateLimitType: "five_hour",
      utilization: 0.85,
      isUsingOverage: false,
      overageStatus: "available"
    }
    msg = ClaudeAgent::RateLimitEvent.new(
      rate_limit_info: info,
      uuid: "msg-123",
      session_id: "session-abc"
    )
    assert_equal info, msg.rate_limit_info
    assert_equal "msg-123", msg.uuid
    assert_equal "session-abc", msg.session_id
    assert_equal "allowed_warning", msg.status
    assert_equal :rate_limit_event, msg.type
  end

  test "rate_limit_event_with_symbol_keys" do
    msg = ClaudeAgent::RateLimitEvent.new(
      rate_limit_info: { status: "blocked" }
    )
    assert_equal "blocked", msg.status
  end

  test "rate_limit_event_defaults" do
    msg = ClaudeAgent::RateLimitEvent.new(rate_limit_info: {})
    assert_nil msg.uuid
    assert_nil msg.session_id
    assert_nil msg.status
  end

  test "rate_limit_event_in_types_constant" do
    assert_includes ClaudeAgent::MESSAGE_TYPES, ClaudeAgent::RateLimitEvent
  end

  test "prompt_suggestion_message" do
    msg = ClaudeAgent::PromptSuggestionMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      suggestion: "Tell me about this project"
    )
    assert_equal "msg-123", msg.uuid
    assert_equal "session-abc", msg.session_id
    assert_equal "Tell me about this project", msg.suggestion
    assert_equal :prompt_suggestion, msg.type
  end

  test "prompt_suggestion_message_defaults" do
    msg = ClaudeAgent::PromptSuggestionMessage.new(suggestion: "Hello")
    assert_nil msg.uuid
    assert_nil msg.session_id
  end

  test "prompt_suggestion_message_in_types_constant" do
    assert_includes ClaudeAgent::MESSAGE_TYPES, ClaudeAgent::PromptSuggestionMessage
  end
end
