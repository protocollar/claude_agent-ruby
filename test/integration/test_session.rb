# frozen_string_literal: true

require_relative "../integration_helper"

class TestIntegrationSession < IntegrationTestCase
  # --- unstable_v2_create_session ---

  test "creates session with options hash" do
    session = ClaudeAgent.unstable_v2_create_session(model: "sonnet")

    assert_instance_of ClaudeAgent::Session, session
    assert_equal "sonnet", session.options.model
    refute session.closed?
  ensure
    session&.close
  end

  test "creates session with SessionOptions" do
    opts = ClaudeAgent::SessionOptions.new(model: "sonnet")
    session = ClaudeAgent.unstable_v2_create_session(opts)

    assert_instance_of ClaudeAgent::Session, session
    assert_equal opts, session.options
  ensure
    session&.close
  end

  # --- Session#send and Session#stream ---

  test "session send and stream messages" do
    session = ClaudeAgent.unstable_v2_create_session(model: "sonnet")

    session.send("Reply with exactly: HELLO")

    messages = []
    session.stream do |msg|
      messages << msg
      break if msg.is_a?(ClaudeAgent::ResultMessage)
    end

    assert messages.any? { |m| m.is_a?(ClaudeAgent::AssistantMessage) }
    assert messages.any? { |m| m.is_a?(ClaudeAgent::ResultMessage) }

    result = messages.find { |m| m.is_a?(ClaudeAgent::ResultMessage) }
    assert_not_nil result
    refute result.is_error
  ensure
    session&.close
  end

  # --- Session#close ---

  test "session close marks as closed" do
    session = ClaudeAgent.unstable_v2_create_session(model: "sonnet")

    refute session.closed?
    session.close
    assert session.closed?
  end

  test "session close is idempotent" do
    session = ClaudeAgent.unstable_v2_create_session(model: "sonnet")

    session.close
    session.close # Should not raise
    assert session.closed?
  end

  # --- unstable_v2_prompt ---

  test "unstable_v2_prompt returns result" do
    result = ClaudeAgent.unstable_v2_prompt(
      "Reply with exactly: TEST",
      model: "sonnet"
    )

    assert_instance_of ClaudeAgent::ResultMessage, result
    refute result.is_error
  end

  # --- Multi-turn conversation ---

  test "multi-turn conversation preserves context" do
    session = ClaudeAgent.unstable_v2_create_session(model: "sonnet")

    # First turn
    session.send("Remember the secret word: BANANA")
    first_result = nil
    session.stream do |msg|
      first_result = msg if msg.is_a?(ClaudeAgent::ResultMessage)
      break if first_result
    end
    assert_not_nil first_result

    # Second turn - should remember context
    session.send("What was the secret word I told you? Reply with just the word.")
    assistant_response = nil
    second_result = nil
    session.stream do |msg|
      assistant_response = msg if msg.is_a?(ClaudeAgent::AssistantMessage)
      second_result = msg if msg.is_a?(ClaudeAgent::ResultMessage)
      break if second_result
    end

    assert_not_nil second_result
    assert_not_nil assistant_response
    assert assistant_response.text.include?("BANANA"), "Expected response to contain 'BANANA'"
  ensure
    session&.close
  end

  # --- Session resumption ---

  test "unstable_v2_resume_session creates resumable session" do
    # First, create a session and get its ID
    original_session = ClaudeAgent.unstable_v2_create_session(model: "sonnet")
    original_session.send("Reply with: ORIGINAL")

    session_id = nil
    original_session.stream do |msg|
      if msg.is_a?(ClaudeAgent::ResultMessage)
        session_id = msg.session_id
        break
      end
    end
    original_session.close

    skip "Session ID not returned" unless session_id

    # Resume the session
    resumed_session = ClaudeAgent.unstable_v2_resume_session(session_id, model: "sonnet")
    assert_instance_of ClaudeAgent::Session, resumed_session
  ensure
    original_session&.close
    resumed_session&.close
  end
end
