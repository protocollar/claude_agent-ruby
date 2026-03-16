# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentPermissionPolicy < ActiveSupport::TestCase
  # --- Basic construction ---

  test "empty policy" do
    policy = ClaudeAgent::PermissionPolicy.new
    assert policy.empty?
  end

  test "policy with block" do
    policy = ClaudeAgent::PermissionPolicy.new do |p|
      p.allow "Read"
    end
    refute policy.empty?
  end

  # --- Allow rules ---

  test "allow exact match" do
    policy = ClaudeAgent::PermissionPolicy.new do |p|
      p.allow "Read", "Grep"
      p.deny_all
    end

    handler = policy.to_can_use_tool
    result = handler.call("Read", {}, nil)
    assert_equal "allow", result.behavior

    result = handler.call("Grep", {}, nil)
    assert_equal "allow", result.behavior
  end

  test "deny exact match" do
    policy = ClaudeAgent::PermissionPolicy.new do |p|
      p.deny "Bash", message: "No shell access"
    end

    handler = policy.to_can_use_tool
    result = handler.call("Bash", {}, nil)
    assert_equal "deny", result.behavior
    assert_equal "No shell access", result.message
  end

  test "deny with interrupt" do
    policy = ClaudeAgent::PermissionPolicy.new do |p|
      p.deny "Bash", message: "Stop", interrupt: true
    end

    handler = policy.to_can_use_tool
    result = handler.call("Bash", {}, nil)
    assert_equal "deny", result.behavior
    assert result.interrupt
  end

  # --- Pattern matching ---

  test "allow_matching with regexp" do
    policy = ClaudeAgent::PermissionPolicy.new do |p|
      p.allow_matching(/^mcp__/)
      p.deny_all
    end

    handler = policy.to_can_use_tool
    result = handler.call("mcp__server__tool", {}, nil)
    assert_equal "allow", result.behavior

    result = handler.call("Read", {}, nil)
    assert_equal "deny", result.behavior
  end

  test "deny_matching with string pattern" do
    policy = ClaudeAgent::PermissionPolicy.new do |p|
      p.deny_matching("^Write|^Edit", message: "Read-only")
      p.allow_all
    end

    handler = policy.to_can_use_tool
    result = handler.call("Write", {}, nil)
    assert_equal "deny", result.behavior

    result = handler.call("Edit", {}, nil)
    assert_equal "deny", result.behavior

    result = handler.call("Read", {}, nil)
    assert_equal "allow", result.behavior
  end

  # --- First match wins ---

  test "first matching rule wins" do
    policy = ClaudeAgent::PermissionPolicy.new do |p|
      p.allow "Bash"
      p.deny "Bash"
    end

    handler = policy.to_can_use_tool
    result = handler.call("Bash", {}, nil)
    assert_equal "allow", result.behavior
  end

  # --- Fallback behaviors ---

  test "allow_all fallback" do
    policy = ClaudeAgent::PermissionPolicy.new do |p|
      p.deny "Bash"
      p.allow_all
    end

    handler = policy.to_can_use_tool
    result = handler.call("Bash", {}, nil)
    assert_equal "deny", result.behavior

    result = handler.call("Read", {}, nil)
    assert_equal "allow", result.behavior
  end

  test "deny_all fallback" do
    policy = ClaudeAgent::PermissionPolicy.new do |p|
      p.allow "Read"
      p.deny_all
    end

    handler = policy.to_can_use_tool
    result = handler.call("Read", {}, nil)
    assert_equal "allow", result.behavior

    result = handler.call("Bash", {}, nil)
    assert_equal "deny", result.behavior
  end

  test "custom fallback handler" do
    policy = ClaudeAgent::PermissionPolicy.new do |p|
      p.allow "Read"
      p.ask { |name, _input, _ctx| ClaudeAgent::PermissionResultDeny.new(message: "Unknown: #{name}") }
    end

    handler = policy.to_can_use_tool
    result = handler.call("Bash", {}, nil)
    assert_equal "deny", result.behavior
    assert_equal "Unknown: Bash", result.message
  end

  test "default fallback is allow" do
    policy = ClaudeAgent::PermissionPolicy.new do |p|
      p.deny "Bash"
    end

    handler = policy.to_can_use_tool
    result = handler.call("Read", {}, nil)
    assert_equal "allow", result.behavior
  end

  # --- to_can_use_tool returns PermissionResult types ---

  test "to_can_use_tool returns PermissionResultAllow" do
    policy = ClaudeAgent::PermissionPolicy.new { |p| p.allow "Read" }
    handler = policy.to_can_use_tool

    result = handler.call("Read", {}, nil)
    assert_instance_of ClaudeAgent::PermissionResultAllow, result
  end

  test "to_can_use_tool returns PermissionResultDeny" do
    policy = ClaudeAgent::PermissionPolicy.new { |p| p.deny "Bash" }
    handler = policy.to_can_use_tool

    result = handler.call("Bash", {}, nil)
    assert_instance_of ClaudeAgent::PermissionResultDeny, result
  end

  # --- Chaining ---

  test "methods return self for chaining" do
    policy = ClaudeAgent::PermissionPolicy.new
    assert_equal policy, policy.allow("Read")
    assert_equal policy, policy.deny("Bash")
    assert_equal policy, policy.allow_matching(/test/)
    assert_equal policy, policy.deny_matching(/test/)
    assert_equal policy, policy.allow_all
    assert_equal policy, policy.deny_all
  end
end
