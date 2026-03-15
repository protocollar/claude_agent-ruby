# frozen_string_literal: true

require_relative "../integration_helper"

class TestIntegrationConversationScenarios < IntegrationTestCase
  test "conversation lifecycle: say, callbacks, cost, session_id, messages, close" do
    texts = []
    results = []

    conversation = ClaudeAgent::Conversation.new(
      max_turns: 1,
      on_text: ->(text) { texts << text },
      on_result: ->(r) { results << r }
    )

    # --- say returns TurnResult ---
    turn = conversation.say("Reply with exactly: LIFECYCLE")
    assert_instance_of ClaudeAgent::TurnResult, turn
    assert turn.complete?
    assert turn.success?
    assert_includes turn.text, "LIFECYCLE"

    # --- auto-connects ---
    assert conversation.open?

    # --- on_text callback fires ---
    assert texts.any? { |t| t.include?("LIFECYCLE") }

    # --- on_result callback fires ---
    assert_equal 1, results.size
    assert_instance_of ClaudeAgent::ResultMessage, results[0]

    # --- cost/usage tracked ---
    assert conversation.total_cost >= 0
    assert conversation.usage.input_tokens > 0
    assert conversation.usage.output_tokens > 0

    # --- session_id available ---
    assert_not_nil conversation.session_id

    # --- messages accumulated ---
    assert conversation.messages.any? { |m| m.is_a?(ClaudeAgent::AssistantMessage) }
    assert conversation.messages.any? { |m| m.is_a?(ClaudeAgent::ResultMessage) }

    # --- inspect includes useful info ---
    output = conversation.inspect
    assert_includes output, "turns=1"
    assert_includes output, "open"

    # --- close works ---
    conversation.close
    assert conversation.closed?

    # --- close is idempotent ---
    conversation.close # should not raise

    # --- say after close raises ---
    assert_raises(ClaudeAgent::Error) do
      conversation.say("Should fail")
    end
  end

  test "conversation multi-turn preserves context" do
    ClaudeAgent::Conversation.open(max_turns: 1) do |c|
      c.say("Remember the secret word: PINEAPPLE")

      turn = c.say("What was the secret word? Reply with just the word.")

      assert_includes turn.text.downcase, "pineapple"
      assert_equal 2, c.turns.size
    end
  end

  test "conversation block form and convenience" do
    # --- Block form auto-closes ---
    closed_ref = nil

    ClaudeAgent::Conversation.open(max_turns: 1) do |c|
      c.say("Reply with exactly: BLOCK")
      assert c.open?
      closed_ref = c
    end

    assert closed_ref.closed?

    # --- ClaudeAgent.conversation convenience ---
    conversation = ClaudeAgent.conversation(max_turns: 1)

    turn = conversation.say("Reply with exactly: CONVENIENCE")

    assert turn.complete?
    assert_includes turn.text, "CONVENIENCE"
  ensure
    conversation&.close
  end

  test "chat: block form, config merge, multi-turn, Session resource" do
    original_config = ClaudeAgent.config
    ClaudeAgent.reset_config!
    ClaudeAgent.max_turns = 1

    session_id = nil
    conversation_ref = nil

    # --- chat block form with global config ---
    ClaudeAgent.chat do |c|
      conversation_ref = c
      turn = c.say("Remember the word: MANGO. Reply with exactly: REMEMBERED")
      assert turn.success?
      assert_includes turn.text, "REMEMBERED"

      turn2 = c.say("What word did I say? Reply with just the word.")
      assert turn2.success?
      assert turn2.text.downcase.include?("mango")

      session_id = c.session_id
      assert_not_nil session_id

      assert_equal 2, c.turns.size
      assert c.total_cost >= 0
    end

    # --- auto-closed ---
    assert conversation_ref.closed?

    # --- Session resource: find, retrieve, rename, reload ---
    skip "No session_id returned" unless session_id

    session = ClaudeAgent::Session.find(session_id)
    assert_not_nil session, "Session.find should return the session"
    assert_equal session_id, session.session_id

    retrieved = ClaudeAgent::Session.retrieve(session_id)
    assert_equal session_id, retrieved.session_id

    session.rename("Chat Integration Test")
    session.reload
    assert_equal "Chat Integration Test", session.custom_title
  ensure
    ClaudeAgent.instance_variable_set(:@config, original_config)
  end
end
