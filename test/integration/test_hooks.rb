# frozen_string_literal: true

require_relative "../integration_helper"

class TestIntegrationHooks < IntegrationTestCase
  test "hook matcher creation" do
    matcher = ClaudeAgent::HookMatcher.new(
      matcher: "Read",
      callbacks: [ ->(input) { input } ]
    )

    assert_equal "Read", matcher.matcher
    assert_equal 1, matcher.callbacks.length

    assert matcher.matches?("Read")
    assert !matcher.matches?("Write")
  end

  test "hook matcher with regex" do
    matcher = ClaudeAgent::HookMatcher.new(
      matcher: /^mcp__/,
      callbacks: [ ->(input) { input } ]
    )

    assert matcher.matches?("mcp__server__tool")
    assert !matcher.matches?("Read")
  end

  test "hook input types" do
    pre = ClaudeAgent::PreToolUseInput.new(
      tool_name: "Read",
      tool_input: { file_path: "/tmp/test" }
    )
    assert_equal "Read", pre.tool_name
    assert_equal({ file_path: "/tmp/test" }, pre.tool_input)

    post = ClaudeAgent::PostToolUseInput.new(
      tool_name: "Read",
      tool_input: { file_path: "/tmp/test" },
      tool_response: "contents"
    )
    assert_equal "Read", post.tool_name
    assert_equal "contents", post.tool_response
  end

  test "hook input base fields" do
    base = ClaudeAgent::BaseHookInput.new(
      hook_event_name: "TestEvent",
      session_id: "session_123",
      transcript_path: "/tmp/transcript.json",
      cwd: "/home/user/project",
      permission_mode: "default"
    )

    assert_equal "TestEvent", base.hook_event_name
    assert_equal "session_123", base.session_id
    assert_equal "/tmp/transcript.json", base.transcript_path
    assert_equal "/home/user/project", base.cwd
    assert_equal "default", base.permission_mode
  end

  test "PostToolUseFailureInput type" do
    input = ClaudeAgent::PostToolUseFailureInput.new(
      hook_event_name: "PostToolUseFailure",
      session_id: "session_123",
      transcript_path: "/tmp/transcript.json",
      cwd: "/home/user",
      permission_mode: "default",
      tool_name: "Bash",
      tool_input: { command: "rm -rf /" },
      error: "Permission denied",
      is_interrupt: false
    )

    assert_equal "PostToolUseFailure", input.hook_event_name
    assert_equal "Bash", input.tool_name
    assert_equal "Permission denied", input.error
    assert_equal false, input.is_interrupt
  end

  test "NotificationInput type" do
    input = ClaudeAgent::NotificationInput.new(
      hook_event_name: "Notification",
      session_id: "session_123",
      transcript_path: "/tmp/transcript.json",
      cwd: "/home/user",
      permission_mode: "default",
      message: "Task completed successfully",
      title: "Done"
    )

    assert_equal "Notification", input.hook_event_name
    assert_equal "Task completed successfully", input.message
    assert_equal "Done", input.title
  end

  test "SessionStartInput type" do
    input = ClaudeAgent::SessionStartInput.new(
      hook_event_name: "SessionStart",
      session_id: "session_123",
      transcript_path: "/tmp/transcript.json",
      cwd: "/home/user",
      permission_mode: "default",
      source: "startup"
    )

    assert_equal "SessionStart", input.hook_event_name
    assert_equal "startup", input.source
  end

  test "SessionEndInput type" do
    input = ClaudeAgent::SessionEndInput.new(
      hook_event_name: "SessionEnd",
      session_id: "session_123",
      transcript_path: "/tmp/transcript.json",
      cwd: "/home/user",
      permission_mode: "default",
      reason: "completed"
    )

    assert_equal "SessionEnd", input.hook_event_name
    assert_equal "completed", input.reason
  end

  test "SubagentStartInput type" do
    input = ClaudeAgent::SubagentStartInput.new(
      hook_event_name: "SubagentStart",
      session_id: "session_123",
      transcript_path: "/tmp/transcript.json",
      cwd: "/home/user",
      permission_mode: "default",
      agent_id: "agent_456",
      agent_type: "explore"
    )

    assert_equal "SubagentStart", input.hook_event_name
    assert_equal "agent_456", input.agent_id
    assert_equal "explore", input.agent_type
  end

  test "SubagentStopInput type" do
    input = ClaudeAgent::SubagentStopInput.new(
      hook_event_name: "SubagentStop",
      session_id: "session_123",
      transcript_path: "/tmp/transcript.json",
      cwd: "/home/user",
      permission_mode: "default",
      stop_hook_active: true
    )

    assert_equal "SubagentStop", input.hook_event_name
    assert_equal true, input.stop_hook_active
  end

  test "StopInput type" do
    input = ClaudeAgent::StopInput.new(
      hook_event_name: "Stop",
      session_id: "session_123",
      transcript_path: "/tmp/transcript.json",
      cwd: "/home/user",
      permission_mode: "default",
      stop_hook_active: false
    )

    assert_equal "Stop", input.hook_event_name
    assert_equal false, input.stop_hook_active
  end

  test "PreCompactInput type" do
    input = ClaudeAgent::PreCompactInput.new(
      hook_event_name: "PreCompact",
      session_id: "session_123",
      transcript_path: "/tmp/transcript.json",
      cwd: "/home/user",
      permission_mode: "default",
      trigger: "auto",
      custom_instructions: "Focus on main logic"
    )

    assert_equal "PreCompact", input.hook_event_name
    assert_equal "auto", input.trigger
    assert_equal "Focus on main logic", input.custom_instructions
  end

  test "PermissionRequestInput type" do
    input = ClaudeAgent::PermissionRequestInput.new(
      hook_event_name: "PermissionRequest",
      session_id: "session_123",
      transcript_path: "/tmp/transcript.json",
      cwd: "/home/user",
      permission_mode: "default",
      tool_name: "Write",
      tool_input: { file_path: "/etc/config" },
      permission_suggestions: [ "allow" ]
    )

    assert_equal "PermissionRequest", input.hook_event_name
    assert_equal "Write", input.tool_name
    assert_equal({ file_path: "/etc/config" }, input.tool_input)
    assert_equal [ "allow" ], input.permission_suggestions
  end

  test "hook input tool_use_id field" do
    pre = ClaudeAgent::PreToolUseInput.new(
      tool_name: "Bash",
      tool_input: { command: "ls" },
      tool_use_id: "tool-123"
    )
    assert_equal "tool-123", pre.tool_use_id

    post = ClaudeAgent::PostToolUseInput.new(
      tool_name: "Bash",
      tool_input: { command: "ls" },
      tool_response: "file.txt",
      tool_use_id: "tool-456"
    )
    assert_equal "tool-456", post.tool_use_id

    failure = ClaudeAgent::PostToolUseFailureInput.new(
      tool_name: "Bash",
      tool_input: { command: "invalid" },
      error: "Command failed",
      tool_use_id: "tool-789"
    )
    assert_equal "tool-789", failure.tool_use_id
  end

  test "SessionStartInput agent_type field" do
    input = ClaudeAgent::SessionStartInput.new(
      source: "startup",
      agent_type: "Plan"
    )

    assert_equal "startup", input.source
    assert_equal "Plan", input.agent_type
  end

  test "NotificationInput notification_type field" do
    input = ClaudeAgent::NotificationInput.new(
      message: "Task completed",
      title: "Done",
      notification_type: "info"
    )

    assert_equal "Task completed", input.message
    assert_equal "Done", input.title
    assert_equal "info", input.notification_type
  end

  test "SubagentStopInput new fields" do
    input = ClaudeAgent::SubagentStopInput.new(
      stop_hook_active: true,
      agent_id: "agent-123",
      agent_transcript_path: "/path/to/transcript.json"
    )

    assert_equal true, input.stop_hook_active
    assert_equal "agent-123", input.agent_id
    assert_equal "/path/to/transcript.json", input.agent_transcript_path
  end
end
