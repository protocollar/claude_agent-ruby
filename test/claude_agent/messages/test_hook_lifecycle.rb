# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentMessagesHookLifecycle < ActiveSupport::TestCase
  test "hook_started_message" do
    msg = ClaudeAgent::HookStartedMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      hook_id: "hook-456",
      hook_name: "my-hook",
      hook_event: "PreToolUse"
    )
    assert_equal "msg-123", msg.uuid
    assert_equal "session-abc", msg.session_id
    assert_equal "hook-456", msg.hook_id
    assert_equal "my-hook", msg.hook_name
    assert_equal "PreToolUse", msg.hook_event
    assert_equal :hook_started, msg.type
  end

  test "hook_started_message_in_types_constant" do
    assert_includes ClaudeAgent::MESSAGE_TYPES, ClaudeAgent::HookStartedMessage
  end

  test "hook_progress_message" do
    msg = ClaudeAgent::HookProgressMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      hook_id: "hook-456",
      hook_name: "my-hook",
      hook_event: "PreToolUse",
      stdout: "Hook output",
      stderr: "Warning",
      output: "Combined output"
    )
    assert_equal "msg-123", msg.uuid
    assert_equal "session-abc", msg.session_id
    assert_equal "hook-456", msg.hook_id
    assert_equal "my-hook", msg.hook_name
    assert_equal "PreToolUse", msg.hook_event
    assert_equal "Hook output", msg.stdout
    assert_equal "Warning", msg.stderr
    assert_equal "Combined output", msg.output
    assert_equal :hook_progress, msg.type
  end

  test "hook_progress_message_defaults" do
    msg = ClaudeAgent::HookProgressMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      hook_id: "hook-456",
      hook_name: "my-hook",
      hook_event: "PreToolUse"
    )
    assert_equal "", msg.stdout
    assert_equal "", msg.stderr
    assert_equal "", msg.output
  end

  test "hook_progress_message_in_types_constant" do
    assert_includes ClaudeAgent::MESSAGE_TYPES, ClaudeAgent::HookProgressMessage
  end

  test "hook_response_message" do
    msg = ClaudeAgent::HookResponseMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      hook_id: "hook-456",
      hook_name: "my-hook",
      hook_event: "PreToolUse",
      stdout: "Hook output",
      stderr: "",
      output: "Combined output",
      exit_code: 0,
      outcome: "success"
    )
    assert_equal "msg-123", msg.uuid
    assert_equal "session-abc", msg.session_id
    assert_equal "hook-456", msg.hook_id
    assert_equal "my-hook", msg.hook_name
    assert_equal "PreToolUse", msg.hook_event
    assert_equal "Hook output", msg.stdout
    assert_equal "", msg.stderr
    assert_equal "Combined output", msg.output
    assert_equal 0, msg.exit_code
    assert_equal "success", msg.outcome
    assert_equal :hook_response, msg.type
  end

  test "hook_response_message_defaults" do
    msg = ClaudeAgent::HookResponseMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      hook_name: "my-hook",
      hook_event: "PreToolUse"
    )
    assert_nil msg.hook_id
    assert_equal "", msg.stdout
    assert_equal "", msg.stderr
    assert_equal "", msg.output
    assert_nil msg.exit_code
    assert_nil msg.outcome
  end

  test "hook_response_message_success?" do
    msg = ClaudeAgent::HookResponseMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      hook_name: "my-hook",
      hook_event: "PreToolUse",
      outcome: "success"
    )
    assert msg.success?
    refute msg.error?
    refute msg.cancelled?
  end

  test "hook_response_message_error?" do
    msg = ClaudeAgent::HookResponseMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      hook_name: "my-hook",
      hook_event: "PreToolUse",
      outcome: "error"
    )
    refute msg.success?
    assert msg.error?
    refute msg.cancelled?
  end

  test "hook_response_message_cancelled?" do
    msg = ClaudeAgent::HookResponseMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      hook_name: "my-hook",
      hook_event: "PreToolUse",
      outcome: "cancelled"
    )
    refute msg.success?
    refute msg.error?
    assert msg.cancelled?
  end

  test "hook_response_message_in_types_constant" do
    assert_includes ClaudeAgent::MESSAGE_TYPES, ClaudeAgent::HookResponseMessage
  end
end
