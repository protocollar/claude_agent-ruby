# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentHooks < ActiveSupport::TestCase
  # --- Hook Events ---

  test "hook_events_constant" do
    assert_includes ClaudeAgent::HOOK_EVENTS, "PreToolUse"
    assert_includes ClaudeAgent::HOOK_EVENTS, "PostToolUse"
    assert_includes ClaudeAgent::HOOK_EVENTS, "PostToolUseFailure"
    assert_includes ClaudeAgent::HOOK_EVENTS, "Notification"
    assert_includes ClaudeAgent::HOOK_EVENTS, "UserPromptSubmit"
    assert_includes ClaudeAgent::HOOK_EVENTS, "SessionStart"
    assert_includes ClaudeAgent::HOOK_EVENTS, "SessionEnd"
    assert_includes ClaudeAgent::HOOK_EVENTS, "Stop"
    assert_includes ClaudeAgent::HOOK_EVENTS, "SubagentStart"
    assert_includes ClaudeAgent::HOOK_EVENTS, "SubagentStop"
    assert_includes ClaudeAgent::HOOK_EVENTS, "PreCompact"
    assert_includes ClaudeAgent::HOOK_EVENTS, "PermissionRequest"
  end

  # --- HookMatcher ---

  test "hook_matcher" do
    matcher = ClaudeAgent::HookMatcher.new(
      matcher: "Bash|Write",
      callbacks: [ ->(input, context) { { continue_: true } } ],
      timeout: 30
    )
    assert_equal "Bash|Write", matcher.matcher
    assert_equal 30, matcher.timeout
    assert_equal 1, matcher.callbacks.size
  end

  test "hook_matcher_matches_pipe_separated" do
    matcher = ClaudeAgent::HookMatcher.new(matcher: "Bash|Write", callbacks: [])
    assert matcher.matches?("Bash")
    assert matcher.matches?("Write")
    refute matcher.matches?("Read")
  end

  test "hook_matcher_matches_regex" do
    matcher = ClaudeAgent::HookMatcher.new(matcher: "^Read.*", callbacks: [])
    assert matcher.matches?("Read")
    assert matcher.matches?("ReadFile")
    refute matcher.matches?("Write")
  end

  # --- HookContext ---

  test "hook_context" do
    context = ClaudeAgent::HookContext.new(tool_use_id: "tool-123")
    assert_equal "tool-123", context.tool_use_id
  end

  test "hook_context_defaults" do
    context = ClaudeAgent::HookContext.new
    assert_nil context.tool_use_id
  end

  # --- BaseHookInput ---

  test "base_hook_input" do
    input = ClaudeAgent::BaseHookInput.new(
      hook_event_name: "TestEvent",
      session_id: "sess-123",
      transcript_path: "/path/to/transcript",
      cwd: "/home/user",
      permission_mode: "acceptEdits"
    )
    assert_equal "TestEvent", input.hook_event_name
    assert_equal "sess-123", input.session_id
    assert_equal "/path/to/transcript", input.transcript_path
    assert_equal "/home/user", input.cwd
    assert_equal "acceptEdits", input.permission_mode
  end

  # --- PreToolUseInput ---

  test "pre_tool_use_input" do
    input = ClaudeAgent::PreToolUseInput.new(
      tool_name: "Bash",
      tool_input: { command: "ls" },
      tool_use_id: "tool-123",
      session_id: "sess-abc"
    )
    assert_equal "PreToolUse", input.hook_event_name
    assert_equal "Bash", input.tool_name
    assert_equal({ command: "ls" }, input.tool_input)
    assert_equal "tool-123", input.tool_use_id
    assert_equal "sess-abc", input.session_id
  end

  test "pre_tool_use_input_without_tool_use_id" do
    input = ClaudeAgent::PreToolUseInput.new(
      tool_name: "Read",
      tool_input: { file_path: "/tmp" }
    )
    assert_nil input.tool_use_id
  end

  # --- PostToolUseInput ---

  test "post_tool_use_input" do
    input = ClaudeAgent::PostToolUseInput.new(
      tool_name: "Bash",
      tool_input: { command: "ls" },
      tool_response: "file1.txt\nfile2.txt",
      tool_use_id: "tool-456",
      session_id: "sess-abc"
    )
    assert_equal "PostToolUse", input.hook_event_name
    assert_equal "Bash", input.tool_name
    assert_equal({ command: "ls" }, input.tool_input)
    assert_equal "file1.txt\nfile2.txt", input.tool_response
    assert_equal "tool-456", input.tool_use_id
  end

  test "post_tool_use_input_without_tool_use_id" do
    input = ClaudeAgent::PostToolUseInput.new(
      tool_name: "Read",
      tool_input: {},
      tool_response: "content"
    )
    assert_nil input.tool_use_id
  end

  # --- PostToolUseFailureInput ---

  test "post_tool_use_failure_input" do
    input = ClaudeAgent::PostToolUseFailureInput.new(
      tool_name: "Bash",
      tool_input: { command: "invalid_cmd" },
      error: "Command not found",
      tool_use_id: "tool-789",
      is_interrupt: false
    )
    assert_equal "PostToolUseFailure", input.hook_event_name
    assert_equal "Bash", input.tool_name
    assert_equal({ command: "invalid_cmd" }, input.tool_input)
    assert_equal "Command not found", input.error
    assert_equal "tool-789", input.tool_use_id
    assert_equal false, input.is_interrupt
  end

  test "post_tool_use_failure_input_with_interrupt" do
    input = ClaudeAgent::PostToolUseFailureInput.new(
      tool_name: "Bash",
      tool_input: {},
      error: "Interrupted",
      is_interrupt: true
    )
    assert_equal true, input.is_interrupt
  end

  # --- NotificationInput ---

  test "notification_input" do
    input = ClaudeAgent::NotificationInput.new(
      message: "Task completed",
      title: "Success",
      notification_type: "info"
    )
    assert_equal "Notification", input.hook_event_name
    assert_equal "Task completed", input.message
    assert_equal "Success", input.title
    assert_equal "info", input.notification_type
  end

  test "notification_input_without_type" do
    input = ClaudeAgent::NotificationInput.new(message: "Something happened")
    assert_nil input.notification_type
    assert_nil input.title
  end

  # --- UserPromptSubmitInput ---

  test "user_prompt_submit_input" do
    input = ClaudeAgent::UserPromptSubmitInput.new(prompt: "Help me debug this")
    assert_equal "UserPromptSubmit", input.hook_event_name
    assert_equal "Help me debug this", input.prompt
  end

  # --- SessionStartInput ---

  test "session_start_input" do
    input = ClaudeAgent::SessionStartInput.new(
      source: "startup",
      agent_type: "Plan"
    )
    assert_equal "SessionStart", input.hook_event_name
    assert_equal "startup", input.source
    assert_equal "Plan", input.agent_type
  end

  test "session_start_input_without_agent_type" do
    input = ClaudeAgent::SessionStartInput.new(source: "resume")
    assert_equal "resume", input.source
    assert_nil input.agent_type
  end

  test "session_start_input_with_model" do
    input = ClaudeAgent::SessionStartInput.new(
      source: "startup",
      model: "claude-sonnet-4-5-20250514"
    )
    assert_equal "startup", input.source
    assert_equal "claude-sonnet-4-5-20250514", input.model
  end

  test "session_start_input_model_default_nil" do
    input = ClaudeAgent::SessionStartInput.new(source: "startup")
    assert_nil input.model
  end

  # --- SessionEndInput ---

  test "session_end_input" do
    input = ClaudeAgent::SessionEndInput.new(reason: "user_interrupt")
    assert_equal "SessionEnd", input.hook_event_name
    assert_equal "user_interrupt", input.reason
  end

  # --- StopInput ---

  test "stop_input" do
    input = ClaudeAgent::StopInput.new(stop_hook_active: true)
    assert_equal "Stop", input.hook_event_name
    assert_equal true, input.stop_hook_active
  end

  test "stop_input_defaults" do
    input = ClaudeAgent::StopInput.new
    assert_equal false, input.stop_hook_active
  end

  # --- SubagentStartInput ---

  test "subagent_start_input" do
    input = ClaudeAgent::SubagentStartInput.new(
      agent_id: "agent-123",
      agent_type: "Explore"
    )
    assert_equal "SubagentStart", input.hook_event_name
    assert_equal "agent-123", input.agent_id
    assert_equal "Explore", input.agent_type
  end

  # --- SubagentStopInput ---

  test "subagent_stop_input" do
    input = ClaudeAgent::SubagentStopInput.new(
      stop_hook_active: true,
      agent_id: "agent-123",
      agent_transcript_path: "/path/to/transcript.json"
    )
    assert_equal "SubagentStop", input.hook_event_name
    assert_equal true, input.stop_hook_active
    assert_equal "agent-123", input.agent_id
    assert_equal "/path/to/transcript.json", input.agent_transcript_path
  end

  test "subagent_stop_input_defaults" do
    input = ClaudeAgent::SubagentStopInput.new
    assert_equal false, input.stop_hook_active
    assert_nil input.agent_id
    assert_nil input.agent_transcript_path
  end

  # --- PreCompactInput ---

  test "pre_compact_input" do
    input = ClaudeAgent::PreCompactInput.new(
      trigger: "auto",
      custom_instructions: "Summarize the key points"
    )
    assert_equal "PreCompact", input.hook_event_name
    assert_equal "auto", input.trigger
    assert_equal "Summarize the key points", input.custom_instructions
  end

  test "pre_compact_input_without_instructions" do
    input = ClaudeAgent::PreCompactInput.new(trigger: "manual")
    assert_nil input.custom_instructions
  end

  # --- PermissionRequestInput ---

  test "permission_request_input" do
    input = ClaudeAgent::PermissionRequestInput.new(
      tool_name: "Write",
      tool_input: { file_path: "/etc/passwd" },
      permission_suggestions: [ { type: "addRules" } ]
    )
    assert_equal "PermissionRequest", input.hook_event_name
    assert_equal "Write", input.tool_name
    assert_equal({ file_path: "/etc/passwd" }, input.tool_input)
    assert_equal [ { type: "addRules" } ], input.permission_suggestions
  end

  test "permission_request_input_without_suggestions" do
    input = ClaudeAgent::PermissionRequestInput.new(
      tool_name: "Bash",
      tool_input: { command: "rm -rf /" }
    )
    assert_nil input.permission_suggestions
  end
end
