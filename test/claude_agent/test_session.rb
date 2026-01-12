# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentSession < ActiveSupport::TestCase
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

  # --- Session ---

  test "session_initializes_with_options" do
    opts = ClaudeAgent::SessionOptions.new(model: "claude-sonnet")
    session = ClaudeAgent::Session.new(opts)
    assert_equal opts, session.options
    assert_nil session.session_id
    refute session.closed?
  end

  test "session_initializes_with_hash" do
    session = ClaudeAgent::Session.new(model: "claude-sonnet")
    assert_equal "claude-sonnet", session.options.model
    assert_instance_of ClaudeAgent::SessionOptions, session.options
  end

  test "session_close_marks_as_closed" do
    session = ClaudeAgent::Session.new(model: "claude-sonnet")
    refute session.closed?
    session.close
    assert session.closed?
  end

  test "session_close_is_idempotent" do
    session = ClaudeAgent::Session.new(model: "claude-sonnet")
    session.close
    session.close # Should not raise
    assert session.closed?
  end

  # --- Module-level V2 API Methods ---

  test "unstable_v2_create_session" do
    session = ClaudeAgent.unstable_v2_create_session(model: "claude-sonnet")
    assert_instance_of ClaudeAgent::Session, session
    assert_equal "claude-sonnet", session.options.model
  end

  test "unstable_v2_create_session_with_options_object" do
    opts = ClaudeAgent::SessionOptions.new(model: "claude-opus")
    session = ClaudeAgent.unstable_v2_create_session(opts)
    assert_instance_of ClaudeAgent::Session, session
    assert_equal opts, session.options
  end

  test "unstable_v2_resume_session" do
    session = ClaudeAgent.unstable_v2_resume_session("session-abc123", model: "claude-sonnet")
    assert_instance_of ClaudeAgent::Session, session
    assert_equal "claude-sonnet", session.options.model
  end

  # Note: Integration tests for send/stream/unstable_v2_prompt would require
  # the Claude CLI to be available and are in test/integration/
end
