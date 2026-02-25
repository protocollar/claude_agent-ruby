# frozen_string_literal: true

require_relative "../integration_helper"

class TestIntegrationConversation < IntegrationTestCase
  # --- Basic say ---

  test "say returns TurnResult" do
    conversation = ClaudeAgent::Conversation.new(max_turns: 1)

    turn = conversation.say("Reply with exactly: HELLO")

    assert_instance_of ClaudeAgent::TurnResult, turn
    assert turn.complete?
    assert turn.success?
    assert_includes turn.text, "HELLO"
  ensure
    conversation&.close
  end

  test "say auto-connects" do
    conversation = ClaudeAgent::Conversation.new(max_turns: 1)

    refute conversation.open?
    conversation.say("Reply with exactly: TEST")
    assert conversation.open?
  ensure
    conversation&.close
  end

  # --- Block form ---

  test "open block form auto-closes" do
    closed_ref = nil

    ClaudeAgent::Conversation.open(max_turns: 1) do |c|
      c.say("Reply with exactly: BLOCK")
      assert c.open?
      closed_ref = c
    end

    assert closed_ref.closed?
  end

  # --- Multi-turn ---

  test "multi-turn preserves context" do
    ClaudeAgent::Conversation.open(max_turns: 1) do |c|
      c.say("Remember the secret word: PINEAPPLE")

      turn = c.say("What was the secret word? Reply with just the word.")

      assert_includes turn.text.downcase, "pineapple"
      assert_equal 2, c.turns.size
    end
  end

  # --- Callbacks ---

  test "on_text callback fires with real CLI" do
    texts = []
    conversation = ClaudeAgent::Conversation.new(
      max_turns: 1,
      on_text: ->(text) { texts << text }
    )

    conversation.say("Reply with exactly: CALLBACK")

    assert texts.any? { |t| t.include?("CALLBACK") }
  ensure
    conversation&.close
  end

  test "on_result callback fires" do
    results = []
    conversation = ClaudeAgent::Conversation.new(
      max_turns: 1,
      on_result: ->(r) { results << r }
    )

    conversation.say("Reply with exactly: RESULT")

    assert_equal 1, results.size
    assert_instance_of ClaudeAgent::ResultMessage, results[0]
  ensure
    conversation&.close
  end

  # --- Usage & Cost ---

  test "tracks cost and usage" do
    ClaudeAgent::Conversation.open(max_turns: 1) do |c|
      c.say("Reply with exactly: COST")

      assert c.total_cost >= 0
      assert c.usage.input_tokens > 0
      assert c.usage.output_tokens > 0
    end
  end

  # --- Session ---

  test "session_id available after say" do
    conversation = ClaudeAgent::Conversation.new(max_turns: 1)

    assert_nil conversation.session_id
    conversation.say("Reply with exactly: SESSION")
    assert_not_nil conversation.session_id
  ensure
    conversation&.close
  end

  # --- Messages ---

  test "accumulates messages" do
    ClaudeAgent::Conversation.open(max_turns: 1) do |c|
      c.say("Reply with exactly: MESSAGES")

      assert c.messages.any? { |m| m.is_a?(ClaudeAgent::AssistantMessage) }
      assert c.messages.any? { |m| m.is_a?(ClaudeAgent::ResultMessage) }
    end
  end

  # --- Lifecycle ---

  test "close is idempotent" do
    conversation = ClaudeAgent::Conversation.new(max_turns: 1)
    conversation.say("Reply with exactly: CLOSE")

    conversation.close
    conversation.close # should not raise
    assert conversation.closed?
  end

  test "say after close raises" do
    conversation = ClaudeAgent::Conversation.new(max_turns: 1)
    conversation.say("Reply with exactly: FIRST")
    conversation.close

    assert_raises(ClaudeAgent::Error) do
      conversation.say("Should fail")
    end
  end

  # --- Module convenience ---

  test "ClaudeAgent.conversation creates working conversation" do
    conversation = ClaudeAgent.conversation(max_turns: 1)

    turn = conversation.say("Reply with exactly: CONVENIENCE")

    assert turn.complete?
    assert_includes turn.text, "CONVENIENCE"
  ensure
    conversation&.close
  end

  # --- Inspect ---

  test "inspect includes useful info" do
    ClaudeAgent::Conversation.open(max_turns: 1) do |c|
      c.say("Reply with exactly: INSPECT")

      output = c.inspect
      assert_includes output, "turns=1"
      assert_includes output, "open"
    end
  end
end
