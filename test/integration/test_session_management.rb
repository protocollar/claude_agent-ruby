# frozen_string_literal: true

require_relative "../integration_helper"

# Integration tests for session mutations against real CLI sessions.
# Requires INTEGRATION=true and Claude Code CLI v2.0.0+.
class TestIntegrationSessionManagement < IntegrationTestCase
  # Run a quick query and return the session_id from the ResultMessage
  def create_real_session
    messages = ClaudeAgent.query(
      prompt: "Reply with exactly: SESSION_TEST",
      options: test_options
    ).to_a

    result = messages.find { |m| m.is_a?(ClaudeAgent::ResultMessage) }
    assert_not_nil result, "Expected ResultMessage from query"
    refute result.is_error, "Query should succeed"

    result.session_id
  end

  # --- get_session_info ---

  test "get_session_info returns info for a real session" do
    session_id = create_real_session

    info = ClaudeAgent.get_session_info(session_id)

    assert_not_nil info, "Expected to find session #{session_id}"
    assert_instance_of ClaudeAgent::SessionInfo, info
    assert_equal session_id, info.session_id
    assert info.file_size > 0
    assert info.last_modified > 0
  end

  test "get_session_info returns nil for nonexistent session" do
    info = ClaudeAgent.get_session_info("00000000-0000-0000-0000-000000000000")
    assert_nil info
  end

  # --- rename_session ---

  test "rename_session updates title on a real session" do
    session_id = create_real_session

    ClaudeAgent.rename_session(session_id, "Integration Test Title")

    info = ClaudeAgent.get_session_info(session_id)
    assert_not_nil info
    assert_equal "Integration Test Title", info.custom_title
    assert_equal "Integration Test Title", info.summary
  end

  # --- tag_session ---

  test "tag_session sets tag on a real session" do
    session_id = create_real_session

    ClaudeAgent.tag_session(session_id, "integration-test")

    info = ClaudeAgent.get_session_info(session_id)
    assert_not_nil info
    assert_equal "integration-test", info.tag
  end

  test "tag_session clears tag on a real session" do
    session_id = create_real_session

    # Set then clear
    ClaudeAgent.tag_session(session_id, "temp-tag")
    ClaudeAgent.tag_session(session_id, nil)

    info = ClaudeAgent.get_session_info(session_id)
    assert_not_nil info
    assert_equal "", info.tag
  end

  # --- list_sessions with offset ---

  test "list_sessions offset skips sessions" do
    all_sessions = ClaudeAgent.list_sessions(dir: Dir.pwd)
    return if all_sessions.length < 2

    offset_sessions = ClaudeAgent.list_sessions(dir: Dir.pwd, offset: 1)
    assert_equal all_sessions.length - 1, offset_sessions.length
    assert_equal all_sessions[1].session_id, offset_sessions.first.session_id
  end

  # --- SessionInfo new fields ---

  test "real sessions have created_at when timestamp is present" do
    session_id = create_real_session

    info = ClaudeAgent.get_session_info(session_id)
    assert_not_nil info

    # created_at may or may not be present depending on CLI version,
    # but if present it should be a positive integer (ms since epoch)
    if info.created_at
      assert_instance_of Integer, info.created_at
      assert info.created_at > 0
    end
  end

  # --- Combined workflow ---

  test "full lifecycle: query, rename, tag, get_session_info, list_sessions" do
    session_id = create_real_session

    # Rename
    ClaudeAgent.rename_session(session_id, "Lifecycle Test")

    # Tag
    ClaudeAgent.tag_session(session_id, "lifecycle")

    # Verify via get_session_info
    info = ClaudeAgent.get_session_info(session_id)
    assert_not_nil info
    assert_equal "Lifecycle Test", info.custom_title
    assert_equal "lifecycle", info.tag

    # Verify via list_sessions
    sessions = ClaudeAgent.list_sessions(dir: Dir.pwd)
    match = sessions.find { |s| s.session_id == session_id }
    assert_not_nil match, "Expected session to appear in list_sessions"
    assert_equal "Lifecycle Test", match.custom_title
    assert_equal "lifecycle", match.tag
  end
end
