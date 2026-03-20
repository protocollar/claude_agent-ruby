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
    assert_includes ClaudeAgent::HOOK_EVENTS, "PostCompact"
    assert_includes ClaudeAgent::HOOK_EVENTS, "PermissionRequest"
    assert_includes ClaudeAgent::HOOK_EVENTS, "InstructionsLoaded"
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
    assert_nil input.last_assistant_message
  end

  test "stop_input_with_last_assistant_message" do
    input = ClaudeAgent::StopInput.new(
      stop_hook_active: true,
      last_assistant_message: "I've completed the task."
    )
    assert_equal true, input.stop_hook_active
    assert_equal "I've completed the task.", input.last_assistant_message
  end

  # --- StopFailureInput ---

  test "stop_failure_input" do
    input = ClaudeAgent::StopFailureInput.new(error: "rate_limit")
    assert_equal "StopFailure", input.hook_event_name
    assert_equal "rate_limit", input.error
  end

  test "stop_failure_input_defaults" do
    input = ClaudeAgent::StopFailureInput.new(error: "server_error")
    assert_nil input.error_details
    assert_nil input.last_assistant_message
  end

  test "stop_failure_input_with_all_fields" do
    input = ClaudeAgent::StopFailureInput.new(
      error: "rate_limit",
      error_details: "Rate limit exceeded for model",
      last_assistant_message: "I was working on..."
    )
    assert_equal "rate_limit", input.error
    assert_equal "Rate limit exceeded for model", input.error_details
    assert_equal "I was working on...", input.last_assistant_message
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
    assert_nil input.agent_type
    assert_nil input.last_assistant_message
  end

  test "subagent_stop_input_with_agent_type_and_last_assistant_message" do
    input = ClaudeAgent::SubagentStopInput.new(
      agent_id: "agent-123",
      agent_type: "Explore",
      last_assistant_message: "Search complete."
    )
    assert_equal "agent-123", input.agent_id
    assert_equal "Explore", input.agent_type
    assert_equal "Search complete.", input.last_assistant_message
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

  # --- PostCompactInput ---

  test "post_compact_event_in_hook_events" do
    assert_includes ClaudeAgent::HOOK_EVENTS, "PostCompact"
  end

  test "post_compact_input" do
    input = ClaudeAgent::PostCompactInput.new(
      trigger: "auto",
      compact_summary: "Summarized the conversation context",
      session_id: "sess-123"
    )
    assert_equal "PostCompact", input.hook_event_name
    assert_equal "auto", input.trigger
    assert_equal "Summarized the conversation context", input.compact_summary
    assert_equal "sess-123", input.session_id
  end

  test "post_compact_input_requires_trigger_and_compact_summary" do
    assert_raises(ArgumentError) do
      ClaudeAgent::PostCompactInput.new(trigger: "auto")
      # Missing required :compact_summary
    end

    assert_raises(ArgumentError) do
      ClaudeAgent::PostCompactInput.new(compact_summary: "summary")
      # Missing required :trigger
    end
  end

  test "post_compact_input_inherits_base_fields" do
    input = ClaudeAgent::PostCompactInput.new(
      trigger: "manual",
      compact_summary: "Key points summarized",
      transcript_path: "/path/to/transcript",
      cwd: "/home/user",
      permission_mode: "default",
      agent_id: "agent-abc",
      agent_type: "Explore"
    )
    assert_equal "/path/to/transcript", input.transcript_path
    assert_equal "/home/user", input.cwd
    assert_equal "default", input.permission_mode
    assert_equal "agent-abc", input.agent_id
    assert_equal "Explore", input.agent_type
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

  # --- SetupInput ---

  test "setup_input" do
    input = ClaudeAgent::SetupInput.new(
      trigger: "init",
      session_id: "abc-123"
    )
    assert_equal "Setup", input.hook_event_name
    assert_equal "init", input.trigger
    assert_equal "abc-123", input.session_id
  end

  test "setup_input_init?" do
    input = ClaudeAgent::SetupInput.new(trigger: "init")
    assert input.init?
    refute input.maintenance?
  end

  test "setup_input_maintenance?" do
    input = ClaudeAgent::SetupInput.new(trigger: "maintenance")
    refute input.init?
    assert input.maintenance?
  end

  test "setup_event_in_hook_events" do
    assert_includes ClaudeAgent::HOOK_EVENTS, "Setup"
  end

  # --- TeammateIdleInput ---

  test "teammate_idle_event_in_hook_events" do
    assert_includes ClaudeAgent::HOOK_EVENTS, "TeammateIdle"
  end

  test "teammate_idle_input" do
    input = ClaudeAgent::TeammateIdleInput.new(
      teammate_name: "alice",
      team_name: "backend-team",
      session_id: "sess-456"
    )
    assert_equal "TeammateIdle", input.hook_event_name
    assert_equal "alice", input.teammate_name
    assert_equal "backend-team", input.team_name
    assert_equal "sess-456", input.session_id
  end

  test "teammate_idle_input_inherits_base_fields" do
    input = ClaudeAgent::TeammateIdleInput.new(
      teammate_name: "bob",
      team_name: "frontend-team",
      transcript_path: "/path/to/transcript",
      cwd: "/home/user",
      permission_mode: "default"
    )
    assert_equal "/path/to/transcript", input.transcript_path
    assert_equal "/home/user", input.cwd
    assert_equal "default", input.permission_mode
  end

  # --- TaskCompletedInput ---

  test "task_completed_event_in_hook_events" do
    assert_includes ClaudeAgent::HOOK_EVENTS, "TaskCompleted"
  end

  test "task_completed_input" do
    input = ClaudeAgent::TaskCompletedInput.new(
      task_id: "task-789",
      task_subject: "Fix login bug",
      task_description: "The login form fails on mobile",
      teammate_name: "alice",
      team_name: "backend-team",
      session_id: "sess-789"
    )
    assert_equal "TaskCompleted", input.hook_event_name
    assert_equal "task-789", input.task_id
    assert_equal "Fix login bug", input.task_subject
    assert_equal "The login form fails on mobile", input.task_description
    assert_equal "alice", input.teammate_name
    assert_equal "backend-team", input.team_name
    assert_equal "sess-789", input.session_id
  end

  test "task_completed_input_with_required_fields_only" do
    input = ClaudeAgent::TaskCompletedInput.new(
      task_id: "task-001",
      task_subject: "Update docs"
    )
    assert_equal "TaskCompleted", input.hook_event_name
    assert_equal "task-001", input.task_id
    assert_equal "Update docs", input.task_subject
    assert_nil input.task_description
    assert_nil input.teammate_name
    assert_nil input.team_name
  end

  test "task_completed_input_inherits_base_fields" do
    input = ClaudeAgent::TaskCompletedInput.new(
      task_id: "task-002",
      task_subject: "Deploy service",
      transcript_path: "/path/to/transcript",
      cwd: "/home/user",
      permission_mode: "acceptEdits"
    )
    assert_equal "/path/to/transcript", input.transcript_path
    assert_equal "/home/user", input.cwd
    assert_equal "acceptEdits", input.permission_mode
  end

  # --- ElicitationInput ---

  test "elicitation_event_in_hook_events" do
    assert_includes ClaudeAgent::HOOK_EVENTS, "Elicitation"
  end

  test "elicitation_input" do
    input = ClaudeAgent::ElicitationInput.new(
      mcp_server_name: "my-server",
      message: "Please provide credentials",
      mode: "modal",
      url: "https://example.com",
      elicitation_id: "elic-123",
      requested_schema: { type: "object" },
      session_id: "sess-abc"
    )
    assert_equal "Elicitation", input.hook_event_name
    assert_equal "my-server", input.mcp_server_name
    assert_equal "Please provide credentials", input.message
    assert_equal "modal", input.mode
    assert_equal "https://example.com", input.url
    assert_equal "elic-123", input.elicitation_id
    assert_equal({ type: "object" }, input.requested_schema)
    assert_equal "sess-abc", input.session_id
  end

  test "elicitation_input_with_required_fields_only" do
    input = ClaudeAgent::ElicitationInput.new(
      mcp_server_name: "server",
      message: "Auth needed"
    )
    assert_equal "Elicitation", input.hook_event_name
    assert_equal "server", input.mcp_server_name
    assert_equal "Auth needed", input.message
    assert_nil input.mode
    assert_nil input.url
    assert_nil input.elicitation_id
    assert_nil input.requested_schema
  end

  # --- ElicitationResultInput ---

  test "elicitation_result_event_in_hook_events" do
    assert_includes ClaudeAgent::HOOK_EVENTS, "ElicitationResult"
  end

  test "elicitation_result_input" do
    input = ClaudeAgent::ElicitationResultInput.new(
      mcp_server_name: "my-server",
      action: "approve",
      elicitation_id: "elic-123",
      mode: "modal",
      content: { token: "abc" },
      session_id: "sess-abc"
    )
    assert_equal "ElicitationResult", input.hook_event_name
    assert_equal "my-server", input.mcp_server_name
    assert_equal "approve", input.action
    assert_equal "elic-123", input.elicitation_id
    assert_equal "modal", input.mode
    assert_equal({ token: "abc" }, input.content)
    assert_equal "sess-abc", input.session_id
  end

  test "elicitation_result_input_with_required_fields_only" do
    input = ClaudeAgent::ElicitationResultInput.new(
      mcp_server_name: "server",
      action: "decline"
    )
    assert_equal "ElicitationResult", input.hook_event_name
    assert_equal "server", input.mcp_server_name
    assert_equal "decline", input.action
    assert_nil input.elicitation_id
    assert_nil input.mode
    assert_nil input.content
  end

  # --- ConfigChangeInput ---

  test "config_change_event_in_hook_events" do
    assert_includes ClaudeAgent::HOOK_EVENTS, "ConfigChange"
  end

  test "config_change_input" do
    input = ClaudeAgent::ConfigChangeInput.new(
      source: "user_settings",
      file_path: "~/.claude/settings.json",
      session_id: "sess-123"
    )
    assert_equal "ConfigChange", input.hook_event_name
    assert_equal "user_settings", input.source
    assert_equal "~/.claude/settings.json", input.file_path
    assert_equal "sess-123", input.session_id
  end

  test "config_change_input_without_file_path" do
    input = ClaudeAgent::ConfigChangeInput.new(source: "skills")
    assert_equal "ConfigChange", input.hook_event_name
    assert_equal "skills", input.source
    assert_nil input.file_path
  end

  test "config_change_input_sources_constant" do
    assert_includes ClaudeAgent::ConfigChangeInput::SOURCES, "user_settings"
    assert_includes ClaudeAgent::ConfigChangeInput::SOURCES, "project_settings"
    assert_includes ClaudeAgent::ConfigChangeInput::SOURCES, "local_settings"
    assert_includes ClaudeAgent::ConfigChangeInput::SOURCES, "policy_settings"
    assert_includes ClaudeAgent::ConfigChangeInput::SOURCES, "skills"
  end

  # --- WorktreeCreateInput ---

  test "worktree_create_event_in_hook_events" do
    assert_includes ClaudeAgent::HOOK_EVENTS, "WorktreeCreate"
  end

  test "worktree_create_input" do
    input = ClaudeAgent::WorktreeCreateInput.new(
      name: "feature-branch",
      session_id: "sess-123"
    )
    assert_equal "WorktreeCreate", input.hook_event_name
    assert_equal "feature-branch", input.name
    assert_equal "sess-123", input.session_id
  end

  test "worktree_create_input_inherits_base_fields" do
    input = ClaudeAgent::WorktreeCreateInput.new(
      name: "my-worktree",
      transcript_path: "/path/to/transcript",
      cwd: "/home/user",
      permission_mode: "default"
    )
    assert_equal "/path/to/transcript", input.transcript_path
    assert_equal "/home/user", input.cwd
    assert_equal "default", input.permission_mode
  end

  # --- WorktreeRemoveInput ---

  test "worktree_remove_event_in_hook_events" do
    assert_includes ClaudeAgent::HOOK_EVENTS, "WorktreeRemove"
  end

  test "worktree_remove_input" do
    input = ClaudeAgent::WorktreeRemoveInput.new(
      worktree_path: "/tmp/worktrees/feature-branch",
      session_id: "sess-456"
    )
    assert_equal "WorktreeRemove", input.hook_event_name
    assert_equal "/tmp/worktrees/feature-branch", input.worktree_path
    assert_equal "sess-456", input.session_id
  end

  test "worktree_remove_input_inherits_base_fields" do
    input = ClaudeAgent::WorktreeRemoveInput.new(
      worktree_path: "/tmp/worktrees/cleanup",
      transcript_path: "/path/to/transcript",
      cwd: "/home/user",
      permission_mode: "acceptEdits"
    )
    assert_equal "/path/to/transcript", input.transcript_path
    assert_equal "/home/user", input.cwd
    assert_equal "acceptEdits", input.permission_mode
  end

  test "config_change_input_inherits_base_fields" do
    input = ClaudeAgent::ConfigChangeInput.new(
      source: "project_settings",
      file_path: ".claude/settings.json",
      transcript_path: "/path/to/transcript",
      cwd: "/home/user",
      permission_mode: "default"
    )
    assert_equal "/path/to/transcript", input.transcript_path
    assert_equal "/home/user", input.cwd
    assert_equal "default", input.permission_mode
  end

  # --- define_input DSL ---

  test "define_input generates class inheriting from BaseHookInput" do
    assert ClaudeAgent::PreToolUseInput < ClaudeAgent::BaseHookInput
    assert ClaudeAgent::StopInput < ClaudeAgent::BaseHookInput
    assert ClaudeAgent::SetupInput < ClaudeAgent::BaseHookInput
  end

  test "define_input generates all 22 input classes" do
    ClaudeAgent::HOOK_EVENTS.each do |event|
      klass = ClaudeAgent.const_get("#{event}Input")
      assert klass < ClaudeAgent::BaseHookInput, "#{event}Input should inherit from BaseHookInput"
    end
  end

  test "define_input raises ArgumentError for missing required fields" do
    assert_raises(ArgumentError) do
      ClaudeAgent::PreToolUseInput.new(tool_name: "Bash")
      # Missing required :tool_input
    end
  end

  test "define_input optional fields default correctly" do
    input = ClaudeAgent::SubagentStopInput.new
    assert_equal false, input.stop_hook_active
    assert_nil input.agent_id
    assert_nil input.agent_transcript_path
  end

  test "define_input with block adds custom methods" do
    input = ClaudeAgent::SetupInput.new(trigger: "init")
    assert_respond_to input, :init?
    assert_respond_to input, :maintenance?
    assert input.init?
    refute input.maintenance?
  end

  test "define_input with constants defines class constants" do
    assert_equal %w[user_settings project_settings local_settings policy_settings skills],
      ClaudeAgent::ConfigChangeInput::SOURCES
  end

  test "define_input forwards unknown kwargs to base class" do
    input = ClaudeAgent::WorktreeCreateInput.new(
      name: "feature",
      session_id: "sess-123",
      transcript_path: "/path",
      cwd: "/home",
      permission_mode: "default"
    )
    assert_equal "WorktreeCreate", input.hook_event_name
    assert_equal "feature", input.name
    assert_equal "sess-123", input.session_id
    assert_equal "/path", input.transcript_path
    assert_equal "/home", input.cwd
    assert_equal "default", input.permission_mode
  end

  # --- BaseHookInput agent_id and agent_type ---

  test "base_hook_input_agent_id_and_agent_type" do
    input = ClaudeAgent::BaseHookInput.new(
      hook_event_name: "TestEvent",
      agent_id: "agent-abc",
      agent_type: "Explore"
    )
    assert_equal "agent-abc", input.agent_id
    assert_equal "Explore", input.agent_type
  end

  test "base_hook_input_agent_id_and_agent_type_default_nil" do
    input = ClaudeAgent::BaseHookInput.new(hook_event_name: "TestEvent")
    assert_nil input.agent_id
    assert_nil input.agent_type
  end

  test "subclass_inherits_agent_id_and_agent_type" do
    input = ClaudeAgent::PreToolUseInput.new(
      tool_name: "Bash",
      tool_input: { command: "ls" },
      agent_id: "agent-xyz",
      agent_type: "Plan"
    )
    assert_equal "agent-xyz", input.agent_id
    assert_equal "Plan", input.agent_type
  end

  # --- InstructionsLoadedInput ---

  test "instructions_loaded_event_in_hook_events" do
    assert_includes ClaudeAgent::HOOK_EVENTS, "InstructionsLoaded"
  end

  test "instructions_loaded_input" do
    input = ClaudeAgent::InstructionsLoadedInput.new(
      file_path: "/home/user/.claude/CLAUDE.md",
      memory_type: "User",
      load_reason: "session_start",
      globs: [ "*.rb" ],
      trigger_file_path: "/home/user/project/src/app.rb",
      parent_file_path: "/home/user/.claude/CLAUDE.md",
      session_id: "sess-123"
    )
    assert_equal "InstructionsLoaded", input.hook_event_name
    assert_equal "/home/user/.claude/CLAUDE.md", input.file_path
    assert_equal "User", input.memory_type
    assert_equal "session_start", input.load_reason
    assert_equal [ "*.rb" ], input.globs
    assert_equal "/home/user/project/src/app.rb", input.trigger_file_path
    assert_equal "/home/user/.claude/CLAUDE.md", input.parent_file_path
    assert_equal "sess-123", input.session_id
  end

  test "instructions_loaded_input_with_required_fields_only" do
    input = ClaudeAgent::InstructionsLoadedInput.new(
      file_path: "/path/to/rules.md",
      memory_type: "Project",
      load_reason: "nested_traversal"
    )
    assert_equal "InstructionsLoaded", input.hook_event_name
    assert_equal "/path/to/rules.md", input.file_path
    assert_equal "Project", input.memory_type
    assert_equal "nested_traversal", input.load_reason
    assert_nil input.globs
    assert_nil input.trigger_file_path
    assert_nil input.parent_file_path
  end

  test "instructions_loaded_input_memory_types_constant" do
    assert_equal %w[User Project Local Managed], ClaudeAgent::InstructionsLoadedInput::MEMORY_TYPES
  end

  test "instructions_loaded_input_load_reasons_constant" do
    assert_equal %w[session_start nested_traversal path_glob_match include],
      ClaudeAgent::InstructionsLoadedInput::LOAD_REASONS
  end

  test "instructions_loaded_input_inherits_base_fields" do
    input = ClaudeAgent::InstructionsLoadedInput.new(
      file_path: "/path/to/file.md",
      memory_type: "Local",
      load_reason: "path_glob_match",
      transcript_path: "/path/to/transcript",
      cwd: "/home/user",
      permission_mode: "default",
      agent_id: "agent-abc",
      agent_type: "Explore"
    )
    assert_equal "/path/to/transcript", input.transcript_path
    assert_equal "/home/user", input.cwd
    assert_equal "default", input.permission_mode
    assert_equal "agent-abc", input.agent_id
    assert_equal "Explore", input.agent_type
  end
end
