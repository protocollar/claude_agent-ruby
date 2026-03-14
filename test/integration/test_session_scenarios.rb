# frozen_string_literal: true

require_relative "../integration_helper"

class TestIntegrationSessionScenarios < IntegrationTestCase
  test "V2 session lifecycle: create, send, stream, close" do
    session = ClaudeAgent.unstable_v2_create_session(model: "sonnet")
    assert_instance_of ClaudeAgent::V2Session, session
    refute session.closed?

    # --- send and stream ---
    session.send("Reply with exactly: HELLO")

    messages = []
    session.stream do |msg|
      messages << msg
      break if msg.is_a?(ClaudeAgent::ResultMessage)
    end

    assert messages.any? { |m| m.is_a?(ClaudeAgent::AssistantMessage) }

    result = messages.find { |m| m.is_a?(ClaudeAgent::ResultMessage) }
    assert_not_nil result
    refute result.is_error

    # --- close ---
    session.close
    assert session.closed?

    # --- close is idempotent ---
    session.close # should not raise
    assert session.closed?
  end

  test "V2 session multi-turn and resumption" do
    session = ClaudeAgent.unstable_v2_create_session(model: "sonnet")

    # First turn
    session.send("Remember the secret word: BANANA")
    session_id = nil
    session.stream do |msg|
      session_id = msg.session_id if msg.is_a?(ClaudeAgent::ResultMessage)
      break if msg.is_a?(ClaudeAgent::ResultMessage)
    end
    assert_not_nil session_id

    # Second turn - should remember context
    session.send("What was the secret word I told you? Reply with just the word.")
    assistant_response = nil
    session.stream do |msg|
      assistant_response = msg if msg.is_a?(ClaudeAgent::AssistantMessage)
      break if msg.is_a?(ClaudeAgent::ResultMessage)
    end

    assert_not_nil assistant_response
    assert assistant_response.text.downcase.include?("banana"),
      "Expected response to contain 'BANANA' (case-insensitive)"

    session.close

    # --- Resumption ---
    skip "Session ID not returned" unless session_id
    resumed_session = ClaudeAgent.unstable_v2_resume_session(session_id, model: "sonnet")
    assert_instance_of ClaudeAgent::V2Session, resumed_session
  ensure
    session&.close
    resumed_session&.close
  end

  test "session management lifecycle: query, rename, tag, get_info, list" do
    # Create a real session via query
    messages = ClaudeAgent.query(
      prompt: "Reply with exactly: SESSION_TEST",
      options: test_options
    ).to_a

    result = messages.find { |m| m.is_a?(ClaudeAgent::ResultMessage) }
    assert_not_nil result, "Expected ResultMessage from query"
    refute result.is_error, "Query should succeed"
    session_id = result.session_id

    # --- get_session_info ---
    info = ClaudeAgent.get_session_info(session_id)
    assert_not_nil info, "Expected to find session #{session_id}"
    assert_instance_of ClaudeAgent::SessionInfo, info
    assert_equal session_id, info.session_id
    assert info.file_size > 0
    assert info.last_modified > 0

    # created_at may or may not be present depending on CLI version
    if info.created_at
      assert_instance_of Integer, info.created_at
      assert info.created_at > 0
    end

    # --- rename_session ---
    ClaudeAgent.rename_session(session_id, "Lifecycle Test")
    info = ClaudeAgent.get_session_info(session_id)
    assert_equal "Lifecycle Test", info.custom_title
    assert_equal "Lifecycle Test", info.summary

    # --- tag_session ---
    ClaudeAgent.tag_session(session_id, "lifecycle")
    info = ClaudeAgent.get_session_info(session_id)
    assert_equal "lifecycle", info.tag

    # --- tag_session clear ---
    ClaudeAgent.tag_session(session_id, nil)
    info = ClaudeAgent.get_session_info(session_id)
    assert_equal "", info.tag

    # --- list_sessions finds it ---
    sessions = ClaudeAgent.list_sessions(dir: Dir.pwd)
    match = sessions.find { |s| s.session_id == session_id }
    assert_not_nil match, "Expected session to appear in list_sessions"

    # --- list_sessions offset ---
    all_sessions = ClaudeAgent.list_sessions(dir: Dir.pwd)
    if all_sessions.length >= 2
      offset_sessions = ClaudeAgent.list_sessions(dir: Dir.pwd, offset: 1)
      assert_equal all_sessions.length - 1, offset_sessions.length
      assert_equal all_sessions[1].session_id, offset_sessions.first.session_id
    end

    # --- get_session_info nil for nonexistent ---
    assert_nil ClaudeAgent.get_session_info("00000000-0000-0000-0000-000000000000")
  end

  test "list_sessions basic operations" do
    # No CLI spawn needed - reads filesystem
    sessions = ClaudeAgent.list_sessions
    assert_instance_of Array, sessions

    sessions.each do |session|
      assert_instance_of ClaudeAgent::SessionInfo, session
      assert_instance_of String, session.session_id
      assert_match ClaudeAgent::SessionPaths::UUID_PATTERN, session.session_id
      assert_instance_of String, session.summary
      assert_instance_of Integer, session.last_modified
      assert session.last_modified > 0
      assert_instance_of Integer, session.file_size
      assert session.file_size > 0
    end

    # sorted descending by last_modified
    if sessions.length >= 2
      sessions.each_cons(2) do |a, b|
        assert a.last_modified >= b.last_modified,
          "Sessions should be sorted desc: #{a.last_modified} < #{b.last_modified}"
      end
    end

    # respects limit
    if sessions.length >= 2
      limited = ClaudeAgent.list_sessions(limit: 1)
      assert_equal 1, limited.length
      assert_equal sessions.first.session_id, limited.first.session_id
    end

    # dir filter
    dir_sessions = ClaudeAgent.list_sessions(dir: Dir.pwd)
    assert_instance_of Array, dir_sessions

    # nonexistent dir returns empty array
    assert_equal [], ClaudeAgent.list_sessions(dir: "/nonexistent/path/that/does/not/exist")
  end
end
