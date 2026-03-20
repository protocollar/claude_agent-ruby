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

  # --- Event mapping ---

  test "before_tool_use maps to PreToolUse" do
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.before_tool_use { |input, ctx| { continue_: true } }
    end
    hooks = registry.to_hooks_hash
    assert hooks.key?("PreToolUse")
    assert_equal 1, hooks["PreToolUse"].size
  end

  test "after_tool_use maps to PostToolUse" do
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.after_tool_use { |input, ctx| { continue_: true } }
    end
    hooks = registry.to_hooks_hash
    assert hooks.key?("PostToolUse")
  end

  test "on_session_start maps to SessionStart" do
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.on_session_start { |input, ctx| { continue_: true } }
    end
    hooks = registry.to_hooks_hash
    assert hooks.key?("SessionStart")
  end

  test "on_stop maps to Stop" do
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.on_stop { |input, ctx| { continue_: true } }
    end
    hooks = registry.to_hooks_hash
    assert hooks.key?("Stop")
  end

  test "all 23 events are mapped" do
    assert_equal 23, ClaudeAgent::HookRegistry::EVENT_MAP.size
  end

  # --- Matcher normalization ---

  test "string matcher passes through" do
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.before_tool_use("Bash") { |_, _| { continue_: true } }
    end
    matcher = registry.to_hooks_hash["PreToolUse"].first
    assert_equal "Bash", matcher.matcher
  end

  test "regexp matcher normalizes to source string" do
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.before_tool_use(/Bash|Write/) { |_, _| { continue_: true } }
    end
    matcher = registry.to_hooks_hash["PreToolUse"].first
    assert_equal "Bash|Write", matcher.matcher
  end

  test "nil matcher passes through" do
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.before_tool_use { |_, _| { continue_: true } }
    end
    matcher = registry.to_hooks_hash["PreToolUse"].first
    assert_nil matcher.matcher
  end

  # --- Timeout ---

  test "timeout passes through to HookMatcher" do
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.before_tool_use(timeout: 30) { |_, _| { continue_: true } }
    end
    matcher = registry.to_hooks_hash["PreToolUse"].first
    assert_equal 30, matcher.timeout
  end

  # --- Multiple matchers per event ---

  test "multiple matchers for same event" do
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.before_tool_use("Bash") { |_, _| { continue_: true } }
      h.before_tool_use("Write") { |_, _| { continue_: false } }
    end
    hooks = registry.to_hooks_hash
    assert_equal 2, hooks["PreToolUse"].size
    assert_equal 2, registry.size
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
    hooks = merged.to_hooks_hash
    assert_equal 2, hooks["PreToolUse"].size
    assert_equal 1, hooks["Stop"].size
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

  # --- to_hooks_hash format ---

  test "to_hooks_hash returns HookMatcher instances" do
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.before_tool_use("Bash") { |_, _| { continue_: true } }
    end
    hooks = registry.to_hooks_hash
    matcher = hooks["PreToolUse"].first
    assert_instance_of ClaudeAgent::HookMatcher, matcher
  end

  test "to_hooks_hash callbacks are wrapped in array" do
    callback = ->(_input, _ctx) { { continue_: true } }
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.before_tool_use("Bash", &callback)
    end
    matcher = registry.to_hooks_hash["PreToolUse"].first
    assert_equal [ callback ], matcher.callbacks
  end

  # --- Chaining ---

  test "methods return self for chaining" do
    registry = ClaudeAgent::HookRegistry.new
    result = registry.before_tool_use { |_, _| {} }
    assert_equal registry, result
  end
end
