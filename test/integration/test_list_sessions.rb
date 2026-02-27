# frozen_string_literal: true

require_relative "../integration_helper"

class TestIntegrationListSessions < IntegrationTestCase
  test "list_sessions returns array of SessionInfo objects" do
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
  end

  test "list_sessions results are sorted by last_modified descending" do
    sessions = ClaudeAgent.list_sessions
    next if sessions.length < 2

    sessions.each_cons(2) do |a, b|
      assert a.last_modified >= b.last_modified,
        "Sessions should be sorted by last_modified desc: #{a.last_modified} < #{b.last_modified}"
    end
  end

  test "list_sessions respects limit" do
    all_sessions = ClaudeAgent.list_sessions
    return if all_sessions.length < 2

    limited = ClaudeAgent.list_sessions(limit: 1)
    assert_equal 1, limited.length
    assert_equal all_sessions.first.session_id, limited.first.session_id
  end

  test "list_sessions with dir filters to current project" do
    sessions = ClaudeAgent.list_sessions(dir: Dir.pwd)
    assert_instance_of Array, sessions

    sessions.each do |session|
      assert_instance_of ClaudeAgent::SessionInfo, session
    end
  end

  test "list_sessions with nonexistent dir returns empty array" do
    sessions = ClaudeAgent.list_sessions(dir: "/nonexistent/path/that/does/not/exist")
    assert_equal [], sessions
  end
end
