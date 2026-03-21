# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentHooks < ActiveSupport::TestCase
  # --- Hook: attributes ---

  test "hook attributes" do
    hook = ClaudeAgent::PreToolUseHook.new(
      matcher: "Bash|Write",
      callbacks: [ ->(input, context) { { continue_: true } } ],
      timeout: 30
    )
    assert_equal "Bash|Write", hook.matcher
    assert_equal 30, hook.timeout
    assert_equal 1, hook.callbacks.size
  end

  # --- Hook: event_name convention ---

  test "event_name derived from subclass name" do
    assert_equal "PreToolUse", ClaudeAgent::PreToolUseHook.event_name
    assert_equal "SessionStart", ClaudeAgent::SessionStartHook.event_name
    assert_equal "PostCompact", ClaudeAgent::PostCompactHook.event_name
    assert_equal "Stop", ClaudeAgent::StopHook.event_name
  end

  test "event_name on instance delegates to class" do
    hook = ClaudeAgent::PreToolUseHook.new(matcher: nil, callbacks: [])
    assert_equal "PreToolUse", hook.event_name
  end

  test "event_name is nil for base Hook class" do
    assert_nil ClaudeAgent::Hook.event_name
  end

  # --- Hook: matches? ---

  test "matches pipe-separated tool names" do
    hook = ClaudeAgent::PreToolUseHook.new(matcher: "Bash|Write", callbacks: [])
    assert hook.matches?("Bash")
    assert hook.matches?("Write")
    refute hook.matches?("Read")
  end

  test "matches regex patterns" do
    hook = ClaudeAgent::PreToolUseHook.new(matcher: "^Read.*", callbacks: [])
    assert hook.matches?("Read")
    assert hook.matches?("ReadFile")
    refute hook.matches?("Write")
  end

  test "nil matcher matches everything" do
    hook = ClaudeAgent::PreToolUseHook.new(matcher: nil, callbacks: [])
    assert hook.matches?("Anything")
  end

  # --- Hook: to_config ---

  test "to_config builds CLI entry and registers callbacks" do
    callback = ->(input, ctx) { { continue_: true } }
    hook = ClaudeAgent::PreToolUseHook.new(
      matcher: "Bash",
      callbacks: [ callback ],
      timeout: 30
    )

    registry = {}
    entry = hook.to_config(0, registry)

    assert_equal "Bash", entry[:matcher]
    assert_equal 30, entry[:timeout]
    assert_equal [ "hook_PreToolUse_0_0" ], entry[:hookCallbackIds]

    registered = registry["hook_PreToolUse_0_0"]
    assert_instance_of ClaudeAgent::Hook::CallbackEntry, registered
    assert_equal hook, registered.hook
    assert_equal callback, registered.callback
  end

  test "to_config omits timeout when nil" do
    hook = ClaudeAgent::StopHook.new(matcher: nil, callbacks: [ ->(i, c) { {} } ])
    entry = hook.to_config(0, {})

    refute entry.key?(:timeout)
  end

  test "to_config handles multiple callbacks" do
    cb1 = ->(i, c) { {} }
    cb2 = ->(i, c) { {} }
    hook = ClaudeAgent::PostToolUseHook.new(matcher: ".*", callbacks: [ cb1, cb2 ])

    registry = {}
    entry = hook.to_config(0, registry)

    assert_equal 2, entry[:hookCallbackIds].size
    assert_equal "hook_PostToolUse_0_0", entry[:hookCallbackIds][0]
    assert_equal "hook_PostToolUse_0_1", entry[:hookCallbackIds][1]
    assert_equal cb1, registry["hook_PostToolUse_0_0"].callback
    assert_equal cb2, registry["hook_PostToolUse_0_1"].callback
  end

  # --- Hook: dispatch ---

  test "dispatch wraps input in HookInput with event_name" do
    received_input = nil
    callback = ->(input, ctx) { received_input = input; {} }
    hook = ClaudeAgent::PreToolUseHook.new(matcher: nil, callbacks: [ callback ])

    hook.dispatch(callback, { tool_name: "Bash", tool_input: {} })

    assert_instance_of ClaudeAgent::HookInput, received_input
    assert_equal "PreToolUse", received_input.hook_event_name
    assert_equal "Bash", received_input.tool_name
  end

  test "dispatch wraps context in HookContext" do
    received_context = nil
    callback = ->(input, ctx) { received_context = ctx; {} }
    hook = ClaudeAgent::SessionStartHook.new(matcher: nil, callbacks: [ callback ])

    hook.dispatch(callback, { source: "startup" }, tool_use_id: "tool-123")

    assert_instance_of ClaudeAgent::HookContext, received_context
    assert_equal "tool-123", received_context.tool_use_id
  end

  test "dispatch returns callback result" do
    callback = ->(input, ctx) { { continue_: true, reason: "approved" } }
    hook = ClaudeAgent::PreToolUseHook.new(matcher: nil, callbacks: [ callback ])

    result = hook.dispatch(callback, { tool_name: "Read" })

    assert_equal true, result[:continue_]
    assert_equal "approved", result[:reason]
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

  # --- HookInput: base fields ---

  test "base fields are accessible as readers" do
    input = ClaudeAgent::HookInput.new(
      hook_event_name: "PreToolUse",
      session_id: "sess-123",
      transcript_path: "/path/to/transcript",
      cwd: "/home/user",
      permission_mode: "acceptEdits",
      agent_id: "agent-abc",
      agent_type: "Explore"
    )
    assert_equal "PreToolUse", input.hook_event_name
    assert_equal "sess-123", input.session_id
    assert_equal "/path/to/transcript", input.transcript_path
    assert_equal "/home/user", input.cwd
    assert_equal "acceptEdits", input.permission_mode
    assert_equal "agent-abc", input.agent_id
    assert_equal "Explore", input.agent_type
  end

  test "base fields default to nil" do
    input = ClaudeAgent::HookInput.new
    assert_nil input.hook_event_name
    assert_nil input.session_id
    assert_nil input.agent_id
  end

  # --- HookInput: dynamic fields via method_missing ---

  test "event-specific fields are accessible via method_missing" do
    input = ClaudeAgent::HookInput.new(
      hook_event_name: "PreToolUse",
      tool_name: "Bash",
      tool_input: { command: "ls" },
      tool_use_id: "tool-123"
    )
    assert_equal "Bash", input.tool_name
    assert_equal({ command: "ls" }, input.tool_input)
    assert_equal "tool-123", input.tool_use_id
  end

  test "respond_to? returns true for dynamic fields" do
    input = ClaudeAgent::HookInput.new(hook_event_name: "Stop", stop_hook_active: true)
    assert_respond_to input, :stop_hook_active
    assert_respond_to input, :hook_event_name
  end

  test "respond_to? returns false for missing fields" do
    input = ClaudeAgent::HookInput.new(hook_event_name: "Stop")
    refute_respond_to input, :nonexistent_field
  end

  test "unknown field raises NoMethodError" do
    input = ClaudeAgent::HookInput.new(hook_event_name: "PreToolUse")
    assert_raises(NoMethodError) { input.nonexistent_field }
  end

  # --- HookInput: [] accessor ---

  test "hash-style access for base fields" do
    input = ClaudeAgent::HookInput.new(hook_event_name: "Setup", session_id: "sess-1")
    assert_equal "Setup", input[:hook_event_name]
    assert_equal "sess-1", input[:session_id]
  end

  test "hash-style access for dynamic fields" do
    input = ClaudeAgent::HookInput.new(hook_event_name: "PreToolUse", tool_name: "Read")
    assert_equal "Read", input[:tool_name]
  end

  test "hash-style access returns nil for missing fields" do
    input = ClaudeAgent::HookInput.new(hook_event_name: "Stop")
    assert_nil input[:nonexistent]
  end

  test "hash-style access works with string keys" do
    input = ClaudeAgent::HookInput.new(hook_event_name: "Stop", trigger: "auto")
    assert_equal "auto", input["trigger"]
  end

  # --- HookInput: to_h ---

  test "to_h includes base and extra fields" do
    input = ClaudeAgent::HookInput.new(
      hook_event_name: "PreToolUse",
      session_id: "sess-1",
      tool_name: "Bash",
      tool_input: { command: "ls" }
    )
    expected = {
      hook_event_name: "PreToolUse",
      session_id: "sess-1",
      tool_name: "Bash",
      tool_input: { command: "ls" }
    }
    assert_equal expected, input.to_h
  end

  test "to_h omits nil base fields" do
    input = ClaudeAgent::HookInput.new(hook_event_name: "Stop", stop_hook_active: true)
    hash = input.to_h
    assert_equal "Stop", hash[:hook_event_name]
    assert_equal true, hash[:stop_hook_active]
    refute hash.key?(:session_id)
    refute hash.key?(:cwd)
  end

  # --- HookInput: fields reader ---

  test "fields exposes extra fields as frozen hash" do
    input = ClaudeAgent::HookInput.new(hook_event_name: "PreToolUse", tool_name: "Bash")
    assert_equal({ tool_name: "Bash" }, input.fields)
    assert input.fields.frozen?
  end

  # --- HookInput: realistic event shapes ---

  test "works as PreToolUse input" do
    input = ClaudeAgent::HookInput.new(
      hook_event_name: "PreToolUse",
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

  test "works as SessionStart input" do
    input = ClaudeAgent::HookInput.new(
      hook_event_name: "SessionStart",
      source: "startup",
      model: "claude-sonnet-4-5-20250514"
    )
    assert_equal "SessionStart", input.hook_event_name
    assert_equal "startup", input.source
    assert_equal "claude-sonnet-4-5-20250514", input.model
  end

  test "works as Stop input with defaults" do
    input = ClaudeAgent::HookInput.new(hook_event_name: "Stop")
    assert_equal "Stop", input.hook_event_name
    assert_nil input.session_id
  end

  test "works as unknown future event" do
    input = ClaudeAgent::HookInput.new(
      hook_event_name: "SomeFutureEvent",
      new_field: "value",
      another_field: 42
    )
    assert_equal "SomeFutureEvent", input.hook_event_name
    assert_equal "value", input.new_field
    assert_equal 42, input.another_field
  end
end
