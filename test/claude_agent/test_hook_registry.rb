# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentHookRegistry < ActiveSupport::TestCase
  # --- Basic construction ---

  test "empty registry" do
    registry = ClaudeAgent::HookRegistry.new
    assert registry.empty?
    assert_equal 0, registry.size
  end

  test "registry with block" do
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.before_tool_use { |input, ctx| { continue_: true } }
    end
    refute registry.empty?
    assert_equal 1, registry.size
  end

  # --- Convention-based event mapping ---

  test "before_ prefix maps to Pre" do
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.before_tool_use { |_, _| { continue_: true } }
      h.before_compact { |_, _| { continue_: true } }
    end
    assert registry.key?("PreToolUse")
    assert registry.key?("PreCompact")
  end

  test "after_ prefix maps to Post" do
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.after_tool_use { |_, _| { continue_: true } }
      h.after_compact { |_, _| { continue_: true } }
      h.after_tool_use_failure { |_, _| { continue_: true } }
    end
    assert registry.key?("PostToolUse")
    assert registry.key?("PostCompact")
    assert registry.key?("PostToolUseFailure")
  end

  test "on_ prefix maps to bare event name" do
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.on_session_start { |_, _| { continue_: true } }
      h.on_stop { |_, _| { continue_: true } }
      h.on_notification { |_, _| { continue_: true } }
    end
    assert registry.key?("SessionStart")
    assert registry.key?("Stop")
    assert registry.key?("Notification")
  end

  test "unknown method raises NoMethodError" do
    registry = ClaudeAgent::HookRegistry.new
    assert_raises(NoMethodError) { registry.not_a_hook_method }
  end

  # --- Register ---

  test "register generates a concrete method and hook class" do
    ClaudeAgent::HookRegistry.register("SomeFutureEvent")

    # Generates the DSL method
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.on_some_future_event { |_, _| { continue_: true } }
    end
    assert registry.key?("SomeFutureEvent")

    # Generates the Hook subclass
    assert ClaudeAgent::SomeFutureEventHook < ClaudeAgent::Hook
    assert_equal "SomeFutureEvent", ClaudeAgent::SomeFutureEventHook.event_name
    assert_instance_of ClaudeAgent::SomeFutureEventHook, registry["SomeFutureEvent"].first
  end

  test "register returns the generated method name" do
    method_name = ClaudeAgent::HookRegistry.register("AnotherFutureEvent")
    assert_equal :on_another_future_event, method_name
  end

  # --- Matcher normalization ---

  test "string matcher passes through" do
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.before_tool_use("Bash") { |_, _| { continue_: true } }
    end
    hook = registry["PreToolUse"].first
    assert_equal "Bash", hook.matcher
  end

  test "regexp matcher normalizes to source string" do
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.before_tool_use(/Bash|Write/) { |_, _| { continue_: true } }
    end
    hook = registry["PreToolUse"].first
    assert_equal "Bash|Write", hook.matcher
  end

  test "nil matcher passes through" do
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.before_tool_use { |_, _| { continue_: true } }
    end
    hook = registry["PreToolUse"].first
    assert_nil hook.matcher
  end

  # --- Timeout ---

  test "timeout passes through to Hook" do
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.before_tool_use(timeout: 30) { |_, _| { continue_: true } }
    end
    hook = registry["PreToolUse"].first
    assert_equal 30, hook.timeout
  end

  # --- Multiple hooks per event ---

  test "multiple hooks for same event" do
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.before_tool_use("Bash") { |_, _| { continue_: true } }
      h.before_tool_use("Write") { |_, _| { continue_: false } }
    end
    assert_equal 2, registry["PreToolUse"].size
    assert_equal 2, registry.size
  end

  # --- Enumerable ---

  test "each iterates over events and hooks" do
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.before_tool_use { |_, _| {} }
      h.on_stop { |_, _| {} }
    end
    events = registry.map { |event, _| event }
    assert_includes events, "PreToolUse"
    assert_includes events, "Stop"
  end

  # --- Merge ---

  test "merge is additive" do
    r1 = ClaudeAgent::HookRegistry.new do |h|
      h.before_tool_use("Bash") { |_, _| { continue_: true } }
    end

    r2 = ClaudeAgent::HookRegistry.new do |h|
      h.before_tool_use("Write") { |_, _| { continue_: true } }
      h.on_stop { |_, _| { continue_: true } }
    end

    merged = r1.merge(r2)
    assert_equal 2, merged["PreToolUse"].size
    assert_equal 1, merged["Stop"].size
    assert_equal 3, merged.size
  end

  test "merge does not modify originals" do
    r1 = ClaudeAgent::HookRegistry.new do |h|
      h.before_tool_use("Bash") { |_, _| { continue_: true } }
    end

    r2 = ClaudeAgent::HookRegistry.new do |h|
      h.before_tool_use("Write") { |_, _| { continue_: true } }
    end

    r1.merge(r2)
    assert_equal 1, r1.size
    assert_equal 1, r2.size
  end

  # --- Hook type ---

  test "hooks are typed subclass instances" do
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.before_tool_use("Bash") { |_, _| { continue_: true } }
    end
    hook = registry["PreToolUse"].first
    assert_instance_of ClaudeAgent::PreToolUseHook, hook
    assert_kind_of ClaudeAgent::Hook, hook
    assert_equal "PreToolUse", hook.event_name
  end

  test "callbacks are wrapped in array" do
    callback = ->(_input, _ctx) { { continue_: true } }
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.before_tool_use("Bash", &callback)
    end
    hook = registry["PreToolUse"].first
    assert_equal [ callback ], hook.callbacks
  end

  # --- from_hash ---

  test "from_hash wraps a plain hooks hash" do
    hook = ClaudeAgent::PreToolUseHook.new(matcher: "Bash", callbacks: [ ->(i, c) { {} } ])
    registry = ClaudeAgent::HookRegistry.from_hash("PreToolUse" => [ hook ])

    assert registry.key?("PreToolUse")
    assert_equal 1, registry["PreToolUse"].size
    assert_equal hook, registry["PreToolUse"].first
  end

  # --- Chaining ---

  test "methods return self for chaining" do
    registry = ClaudeAgent::HookRegistry.new
    result = registry.before_tool_use { |_, _| {} }
    assert_equal registry, result
  end
end
