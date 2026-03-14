# frozen_string_literal: true

require_relative "../integration_helper"

class TestIntegrationQueryScenarios < IntegrationTestCase
  test "query lifecycle: messages, fields, and content" do
    messages = ClaudeAgent.query(
      prompt: "Reply with exactly: HELLO WORLD",
      options: test_options
    ).to_a

    assert messages.length >= 2, "Expected at least 2 messages (system + result)"

    # --- SystemMessage ---
    system_msg = messages.find { |m| m.is_a?(ClaudeAgent::SystemMessage) }
    assert_not_nil system_msg, "Expected SystemMessage"
    assert_equal :system, system_msg.type
    assert_equal "init", system_msg.subtype
    assert_not_nil system_msg.data

    # --- AssistantMessage ---
    assistant = messages.find { |m| m.is_a?(ClaudeAgent::AssistantMessage) }
    assert_not_nil assistant, "Expected AssistantMessage"
    assert_equal :assistant, assistant.type
    assert_not_nil assistant.model
    assert_not_nil assistant.content
    assert assistant.content.is_a?(Array)
    assert assistant.text.length > 0, "Expected non-empty text"

    # --- ResultMessage ---
    result = messages.find { |m| m.is_a?(ClaudeAgent::ResultMessage) }
    assert_not_nil result, "Expected ResultMessage"
    assert_equal false, result.is_error
    assert_not_nil result.session_id, "Expected session_id"
    assert_not_nil result.duration_ms, "Expected duration_ms"
    assert_not_nil result.num_turns, "Expected num_turns"

    if result.total_cost_usd
      assert result.total_cost_usd >= 0, "Cost should be non-negative"
    end

    if result.stop_reason
      assert result.stop_reason.is_a?(String), "stop_reason should be a String"
    end
  end

  test "query with custom options" do
    options = ClaudeAgent::Options.new(
      max_turns: 1,
      system_prompt: "You are a helpful assistant. Always be concise."
    )

    messages = ClaudeAgent.query(
      prompt: "Say hello in exactly one word",
      options: options
    ).to_a

    result = messages.find { |m| m.is_a?(ClaudeAgent::ResultMessage) }
    assert_not_nil result
    assert result.num_turns <= 1, "Expected max 1 turn"
  end
end
