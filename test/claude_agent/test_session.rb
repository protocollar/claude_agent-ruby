# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentV2Session < ActiveSupport::TestCase
  # --- SessionOptions ---

  test "session_options_creates_with_model" do
    opts = ClaudeAgent::SessionOptions.new(model: "claude-sonnet")
    assert_equal "claude-sonnet", opts.model
  end

  test "session_options_defaults" do
    opts = ClaudeAgent::SessionOptions.new(model: "claude-sonnet")
    assert_nil opts.path_to_claude_code_executable
    assert_nil opts.env
    assert_nil opts.allowed_tools
    assert_nil opts.disallowed_tools
    assert_nil opts.can_use_tool
    assert_nil opts.hooks
    assert_nil opts.permission_mode
  end

  test "session_options_with_all_fields" do
    callback = ->(tool, input, ctx) { ClaudeAgent::PermissionResultAllow.new }
    opts = ClaudeAgent::SessionOptions.new(
      model: "claude-opus",
      path_to_claude_code_executable: "/usr/local/bin/claude",
      env: { "CUSTOM_VAR" => "value" },
      allowed_tools: %w[Read Write],
      disallowed_tools: %w[Bash],
      can_use_tool: callback,
      hooks: {},
      permission_mode: "acceptEdits"
    )
    assert_equal "claude-opus", opts.model
    assert_equal "/usr/local/bin/claude", opts.path_to_claude_code_executable
    assert_equal({ "CUSTOM_VAR" => "value" }, opts.env)
    assert_equal %w[Read Write], opts.allowed_tools
    assert_equal %w[Bash], opts.disallowed_tools
    assert_equal callback, opts.can_use_tool
    assert_equal({}, opts.hooks)
    assert_equal "acceptEdits", opts.permission_mode
  end

  # --- V2Session ---

  test "v2session_initializes_with_options" do
    opts = ClaudeAgent::SessionOptions.new(model: "claude-sonnet")
    session = ClaudeAgent::V2Session.new(opts)
    assert_equal opts, session.options
    assert_nil session.session_id
    refute session.closed?
  end

  test "v2session_initializes_with_hash" do
    session = ClaudeAgent::V2Session.new(model: "claude-sonnet")
    assert_equal "claude-sonnet", session.options.model
    assert_instance_of ClaudeAgent::SessionOptions, session.options
  end

  test "v2session_close_marks_as_closed" do
    session = ClaudeAgent::V2Session.new(model: "claude-sonnet")
    refute session.closed?
    session.close
    assert session.closed?
  end

  test "v2session_close_is_idempotent" do
    session = ClaudeAgent::V2Session.new(model: "claude-sonnet")
    session.close
    session.close # Should not raise
    assert session.closed?
  end

  # --- Module-level V2 API Methods ---

  test "unstable_v2_create_session" do
    session = ClaudeAgent.unstable_v2_create_session(model: "claude-sonnet")
    assert_instance_of ClaudeAgent::V2Session, session
    assert_equal "claude-sonnet", session.options.model
  end

  test "unstable_v2_create_session_with_options_object" do
    opts = ClaudeAgent::SessionOptions.new(model: "claude-opus")
    session = ClaudeAgent.unstable_v2_create_session(opts)
    assert_instance_of ClaudeAgent::V2Session, session
    assert_equal opts, session.options
  end

  test "unstable_v2_resume_session" do
    session = ClaudeAgent.unstable_v2_resume_session("session-abc123", model: "claude-sonnet")
    assert_instance_of ClaudeAgent::V2Session, session
    assert_equal "claude-sonnet", session.options.model
  end

  # Note: Integration tests for send/stream/unstable_v2_prompt would require
  # the Claude CLI to be available and are in test/integration/
end

class TestClaudeAgentSession < ActiveSupport::TestCase
  def sample_session_info(overrides = {})
    ClaudeAgent::SessionInfo.new(**{
      session_id: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
      summary: "Fix login bug",
      last_modified: 1706000000000,
      file_size: 4096,
      custom_title: "Login fix",
      first_prompt: "Help me fix the login page",
      git_branch: "fix/login",
      cwd: "/Users/dev/myapp"
    }.merge(overrides))
  end

  # --- Session.find ---

  test "find returns session when found" do
    info = sample_session_info
    ClaudeAgent::ListSessions.stubs(:call).with(dir: nil).returns([ info ])

    session = ClaudeAgent::Session.find("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")

    assert_instance_of ClaudeAgent::Session, session
    assert_equal "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", session.session_id
    assert_equal "Fix login bug", session.summary
    assert_equal 1706000000000, session.last_modified
    assert_equal 4096, session.file_size
    assert_equal "Login fix", session.custom_title
    assert_equal "Help me fix the login page", session.first_prompt
    assert_equal "fix/login", session.git_branch
    assert_equal "/Users/dev/myapp", session.cwd
  end

  test "find returns nil when not found" do
    ClaudeAgent::ListSessions.stubs(:call).with(dir: nil).returns([])

    session = ClaudeAgent::Session.find("nonexistent-id")

    assert_nil session
  end

  test "find passes dir option" do
    info = sample_session_info
    ClaudeAgent::ListSessions.stubs(:call).with(dir: "/my/project").returns([ info ])

    session = ClaudeAgent::Session.find("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", dir: "/my/project")

    assert_instance_of ClaudeAgent::Session, session
  end

  # --- Session.all ---

  test "all returns array of all sessions" do
    infos = [
      sample_session_info(session_id: "11111111-1111-1111-1111-111111111111", summary: "First"),
      sample_session_info(session_id: "22222222-2222-2222-2222-222222222222", summary: "Second")
    ]
    ClaudeAgent::ListSessions.stubs(:call).with.returns(infos)

    sessions = ClaudeAgent::Session.all

    assert_equal 2, sessions.length
    assert sessions.all? { |s| s.is_a?(ClaudeAgent::Session) }
    assert_equal "First", sessions[0].summary
    assert_equal "Second", sessions[1].summary
  end

  # --- Session.where ---

  test "where returns array of sessions" do
    infos = [
      sample_session_info(session_id: "11111111-1111-1111-1111-111111111111", summary: "First")
    ]
    ClaudeAgent::ListSessions.stubs(:call).with(dir: "/project", limit: 5).returns(infos)

    sessions = ClaudeAgent::Session.where(dir: "/project", limit: 5)

    assert_equal 1, sessions.length
    assert sessions.all? { |s| s.is_a?(ClaudeAgent::Session) }
  end

  test "where with no args returns all sessions" do
    infos = [
      sample_session_info(session_id: "11111111-1111-1111-1111-111111111111", summary: "First")
    ]
    ClaudeAgent::ListSessions.stubs(:call).with(dir: nil, limit: nil).returns(infos)

    sessions = ClaudeAgent::Session.where

    assert_equal 1, sessions.length
  end

  # --- Session#messages ---

  test "messages returns SessionMessageRelation" do
    info = sample_session_info
    session = ClaudeAgent::Session.new(info)

    relation = session.messages

    assert_instance_of ClaudeAgent::SessionMessageRelation, relation
  end

  test "messages relation delegates to GetSessionMessages" do
    info = sample_session_info
    session = ClaudeAgent::Session.new(info)

    expected_messages = [
      ClaudeAgent::SessionMessage.new(type: "user", uuid: "u1", session_id: "s1", message: {}),
      ClaudeAgent::SessionMessage.new(type: "assistant", uuid: "u2", session_id: "s1", message: {})
    ]
    ClaudeAgent::GetSessionMessages.stubs(:call)
      .with("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", dir: "/Users/dev/myapp", limit: nil, offset: nil)
      .returns(expected_messages)

    result = session.messages.to_a

    assert_equal 2, result.length
    assert_equal "user", result[0].type
    assert_equal "assistant", result[1].type
  end
end

class TestClaudeAgentSessionMessageRelation < ActiveSupport::TestCase
  def sample_messages
    [
      ClaudeAgent::SessionMessage.new(type: "user", uuid: "u1", session_id: "s1", message: {}),
      ClaudeAgent::SessionMessage.new(type: "assistant", uuid: "u2", session_id: "s1", message: {}),
      ClaudeAgent::SessionMessage.new(type: "user", uuid: "u3", session_id: "s1", message: {})
    ]
  end

  test "is Enumerable" do
    relation = ClaudeAgent::SessionMessageRelation.new("sid")
    assert_kind_of Enumerable, relation
  end

  test "each iterates over messages" do
    ClaudeAgent::GetSessionMessages.stubs(:call)
      .with("sid", dir: nil, limit: nil, offset: nil)
      .returns(sample_messages)

    relation = ClaudeAgent::SessionMessageRelation.new("sid")
    types = relation.map(&:type)

    assert_equal %w[user assistant user], types
  end

  test "where returns new relation with limit" do
    all_msgs = sample_messages
    limited = [ all_msgs[0] ]

    ClaudeAgent::GetSessionMessages.stubs(:call)
      .with("sid", dir: nil, limit: 1, offset: nil)
      .returns(limited)

    relation = ClaudeAgent::SessionMessageRelation.new("sid")
    filtered = relation.where(limit: 1)

    refute_same relation, filtered
    assert_equal 1, filtered.to_a.length
  end

  test "where returns new relation with offset" do
    all_msgs = sample_messages
    offset_msgs = [ all_msgs[1], all_msgs[2] ]

    ClaudeAgent::GetSessionMessages.stubs(:call)
      .with("sid", dir: nil, limit: nil, offset: 1)
      .returns(offset_msgs)

    relation = ClaudeAgent::SessionMessageRelation.new("sid")
    filtered = relation.where(offset: 1)

    assert_equal 2, filtered.to_a.length
    assert_equal "assistant", filtered.first.type
  end

  test "where with limit and offset" do
    limited = [ sample_messages[1] ]

    ClaudeAgent::GetSessionMessages.stubs(:call)
      .with("sid", dir: nil, limit: 1, offset: 1)
      .returns(limited)

    relation = ClaudeAgent::SessionMessageRelation.new("sid")
    filtered = relation.where(limit: 1, offset: 1)

    assert_equal 1, filtered.to_a.length
    assert_equal "assistant", filtered.first.type
  end

  test "chaining where calls" do
    limited = [ sample_messages[2] ]

    ClaudeAgent::GetSessionMessages.stubs(:call)
      .with("sid", dir: nil, limit: 1, offset: 2)
      .returns(limited)

    relation = ClaudeAgent::SessionMessageRelation.new("sid")
    # First set offset, then override with limit+offset
    filtered = relation.where(offset: 2).where(limit: 1)

    assert_equal 1, filtered.to_a.length
  end

  test "results are memoized" do
    ClaudeAgent::GetSessionMessages.stubs(:call)
      .with("sid", dir: nil, limit: nil, offset: nil)
      .returns(sample_messages)
      .once

    relation = ClaudeAgent::SessionMessageRelation.new("sid")

    # Call twice — GetSessionMessages.call should only be invoked once
    relation.to_a
    relation.to_a
  end

  test "to_a returns a copy" do
    ClaudeAgent::GetSessionMessages.stubs(:call)
      .with("sid", dir: nil, limit: nil, offset: nil)
      .returns(sample_messages)

    relation = ClaudeAgent::SessionMessageRelation.new("sid")
    first = relation.to_a
    second = relation.to_a

    refute_same first, second
  end

  test "first returns first message" do
    ClaudeAgent::GetSessionMessages.stubs(:call)
      .with("sid", dir: nil, limit: nil, offset: nil)
      .returns(sample_messages)

    relation = ClaudeAgent::SessionMessageRelation.new("sid")

    assert_equal "user", relation.first.type
    assert_equal "u1", relation.first.uuid
  end

  test "count returns message count" do
    ClaudeAgent::GetSessionMessages.stubs(:call)
      .with("sid", dir: nil, limit: nil, offset: nil)
      .returns(sample_messages)

    relation = ClaudeAgent::SessionMessageRelation.new("sid")

    assert_equal 3, relation.count
  end

  test "select filters messages" do
    ClaudeAgent::GetSessionMessages.stubs(:call)
      .with("sid", dir: nil, limit: nil, offset: nil)
      .returns(sample_messages)

    relation = ClaudeAgent::SessionMessageRelation.new("sid")
    users = relation.select { |m| m.type == "user" }

    assert_equal 2, users.length
  end

  test "passes dir to GetSessionMessages" do
    ClaudeAgent::GetSessionMessages.stubs(:call)
      .with("sid", dir: "/my/project", limit: nil, offset: nil)
      .returns([])

    relation = ClaudeAgent::SessionMessageRelation.new("sid", dir: "/my/project")

    assert_equal [], relation.to_a
  end
end
