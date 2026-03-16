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

  test "ask: returns TurnResult, streams via block, respects config overrides" do
    # Set global config
    original_config = ClaudeAgent.config
    ClaudeAgent.reset_config!
    ClaudeAgent.max_turns = 1

    streamed = []
    turn = ClaudeAgent.ask("Reply with exactly: ASK_TEST") { |msg| streamed << msg }

    # --- Returns TurnResult ---
    assert_instance_of ClaudeAgent::TurnResult, turn
    assert turn.complete?
    assert turn.success?
    assert_includes turn.text, "ASK_TEST"

    # --- Block receives messages ---
    assert streamed.any?, "Expected block to receive messages"
    assert streamed.any? { |m| m.is_a?(ClaudeAgent::AssistantMessage) }
    assert streamed.any? { |m| m.is_a?(ClaudeAgent::ResultMessage) }

    # --- Message module works on real messages ---
    assistant = streamed.find { |m| m.is_a?(ClaudeAgent::AssistantMessage) }
    assert_not_empty assistant.text_content
    assert assistant.session_message?
    assert assistant.identifiable?

    # --- Per-request override wins ---
    turn2 = ClaudeAgent.ask("Reply with exactly: OVERRIDE", system_prompt: "Be terse.")
    assert turn2.success?
  ensure
    ClaudeAgent.instance_variable_set(:@config, original_config)
  end

  test "ask: PermissionPolicy flows through to CLI" do
    policy = ClaudeAgent::PermissionPolicy.new do |p|
      p.allow "Read", "Grep", "Glob"
      p.deny_all message: "Denied by test policy"
    end

    # The policy compiles and runs against the real CLI without error
    turn = ClaudeAgent.ask(
      "Reply with exactly: POLICY_TEST",
      options: ClaudeAgent::Options.new(max_turns: 1, can_use_tool: policy)
    )

    assert turn.success?
    assert_includes turn.text, "POLICY_TEST"
  end
end
