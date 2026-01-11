# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentPermissions < ActiveSupport::TestCase
  # --- Permission Modes ---

  test "permission_modes_constant" do
    assert_includes ClaudeAgent::PERMISSION_MODES, "default"
    assert_includes ClaudeAgent::PERMISSION_MODES, "acceptEdits"
    assert_includes ClaudeAgent::PERMISSION_MODES, "plan"
    assert_includes ClaudeAgent::PERMISSION_MODES, "bypassPermissions"
    assert_includes ClaudeAgent::PERMISSION_MODES, "delegate"
    assert_includes ClaudeAgent::PERMISSION_MODES, "dontAsk"
    assert_equal 6, ClaudeAgent::PERMISSION_MODES.size
  end

  # --- Permission Update Types ---

  test "permission_update_types_constant" do
    assert_includes ClaudeAgent::PERMISSION_UPDATE_TYPES, "addRules"
    assert_includes ClaudeAgent::PERMISSION_UPDATE_TYPES, "replaceRules"
    assert_includes ClaudeAgent::PERMISSION_UPDATE_TYPES, "removeRules"
    assert_includes ClaudeAgent::PERMISSION_UPDATE_TYPES, "setMode"
    assert_includes ClaudeAgent::PERMISSION_UPDATE_TYPES, "addDirectories"
    assert_includes ClaudeAgent::PERMISSION_UPDATE_TYPES, "removeDirectories"
  end

  # --- Permission Update Destinations ---

  test "permission_update_destinations_constant" do
    assert_includes ClaudeAgent::PERMISSION_UPDATE_DESTINATIONS, "userSettings"
    assert_includes ClaudeAgent::PERMISSION_UPDATE_DESTINATIONS, "projectSettings"
    assert_includes ClaudeAgent::PERMISSION_UPDATE_DESTINATIONS, "localSettings"
    assert_includes ClaudeAgent::PERMISSION_UPDATE_DESTINATIONS, "session"
    assert_includes ClaudeAgent::PERMISSION_UPDATE_DESTINATIONS, "cliArg"
    assert_equal 5, ClaudeAgent::PERMISSION_UPDATE_DESTINATIONS.size
  end

  # --- PermissionResultAllow ---

  test "permission_result_allow" do
    result = ClaudeAgent::PermissionResultAllow.new
    assert_equal "allow", result.behavior
    assert_nil result.updated_input
    assert_nil result.updated_permissions
  end

  test "permission_result_allow_with_updated_input" do
    result = ClaudeAgent::PermissionResultAllow.new(
      updated_input: { command: "ls -la" }
    )
    assert_equal({ command: "ls -la" }, result.updated_input)
  end

  test "permission_result_allow_to_h" do
    result = ClaudeAgent::PermissionResultAllow.new
    assert_equal({ behavior: "allow" }, result.to_h)
  end

  test "permission_result_allow_to_h_with_updated_input" do
    result = ClaudeAgent::PermissionResultAllow.new(
      updated_input: { safe: true }
    )
    h = result.to_h
    assert_equal "allow", h[:behavior]
    assert_equal({ safe: true }, h[:updatedInput])
  end

  # --- PermissionResultDeny ---

  test "permission_result_deny" do
    result = ClaudeAgent::PermissionResultDeny.new(
      message: "Operation not allowed",
      interrupt: true
    )
    assert_equal "deny", result.behavior
    assert_equal "Operation not allowed", result.message
    assert_equal true, result.interrupt
  end

  test "permission_result_deny_defaults" do
    result = ClaudeAgent::PermissionResultDeny.new
    assert_equal "", result.message
    assert_equal false, result.interrupt
  end

  test "permission_result_deny_to_h" do
    result = ClaudeAgent::PermissionResultDeny.new(
      message: "Blocked",
      interrupt: true
    )
    assert_equal(
      { behavior: "deny", message: "Blocked", interrupt: true },
      result.to_h
    )
  end

  # --- PermissionUpdate ---

  test "permission_update_add_rules" do
    update = ClaudeAgent::PermissionUpdate.new(
      type: "addRules",
      rules: [ { tool_name: "Read", rule_content: "/**" } ],
      behavior: "allow"
    )
    assert_equal "addRules", update.type
    assert_equal "allow", update.behavior
    assert_equal 1, update.rules.size
  end

  test "permission_update_set_mode" do
    update = ClaudeAgent::PermissionUpdate.new(
      type: "setMode",
      mode: "acceptEdits"
    )
    assert_equal "setMode", update.type
    assert_equal "acceptEdits", update.mode
  end

  test "permission_update_add_directories" do
    update = ClaudeAgent::PermissionUpdate.new(
      type: "addDirectories",
      directories: [ "/home/user/project" ],
      destination: "session"
    )
    assert_equal "addDirectories", update.type
    assert_equal [ "/home/user/project" ], update.directories
    assert_equal "session", update.destination
  end

  test "permission_update_to_h" do
    update = ClaudeAgent::PermissionUpdate.new(
      type: "addRules",
      rules: [ { tool_name: "Read", rule_content: "/**" } ],
      behavior: "allow",
      destination: "cliArg"
    )
    h = update.to_h
    assert_equal "addRules", h[:type]
    assert_equal "allow", h[:behavior]
    assert_equal "cliArg", h[:destination]
    assert_equal [ { toolName: "Read", ruleContent: "/**" } ], h[:rules]
  end

  test "permission_update_normalizes_snake_case_keys" do
    update = ClaudeAgent::PermissionUpdate.new(
      type: "addRules",
      rules: [ { tool_name: "Bash", rule_content: "ls" } ]
    )
    h = update.to_h
    assert_equal "Bash", h[:rules].first[:toolName]
    assert_equal "ls", h[:rules].first[:ruleContent]
  end

  # --- PermissionRuleValue ---

  test "permission_rule_value" do
    rule = ClaudeAgent::PermissionRuleValue.new(
      tool_name: "Write",
      rule_content: "/tmp/**"
    )
    assert_equal "Write", rule.tool_name
    assert_equal "/tmp/**", rule.rule_content
  end

  test "permission_rule_value_to_h" do
    rule = ClaudeAgent::PermissionRuleValue.new(
      tool_name: "Read",
      rule_content: "/home/**"
    )
    h = rule.to_h
    assert_equal "Read", h[:toolName]
    assert_equal "/home/**", h[:ruleContent]
  end

  test "permission_rule_value_to_h_compacts_nil" do
    rule = ClaudeAgent::PermissionRuleValue.new(tool_name: "Bash")
    h = rule.to_h
    assert_equal "Bash", h[:toolName]
    refute h.key?(:ruleContent)
  end

  # --- ToolPermissionContext ---

  test "tool_permission_context" do
    context = ClaudeAgent::ToolPermissionContext.new(
      permission_suggestions: [ { type: "addRules" } ],
      blocked_path: "/etc/passwd",
      decision_reason: "Path outside allowed directories",
      tool_use_id: "tool-123",
      agent_id: "agent-456"
    )
    assert_equal [ { type: "addRules" } ], context.permission_suggestions
    assert_equal "/etc/passwd", context.blocked_path
    assert_equal "Path outside allowed directories", context.decision_reason
    assert_equal "tool-123", context.tool_use_id
    assert_equal "agent-456", context.agent_id
  end

  test "tool_permission_context_defaults" do
    context = ClaudeAgent::ToolPermissionContext.new
    assert_nil context.permission_suggestions
    assert_nil context.blocked_path
    assert_nil context.decision_reason
    assert_nil context.tool_use_id
    assert_nil context.agent_id
  end

  test "tool_permission_context_partial" do
    context = ClaudeAgent::ToolPermissionContext.new(
      tool_use_id: "tool-789",
      decision_reason: "Custom reason"
    )
    assert_equal "tool-789", context.tool_use_id
    assert_equal "Custom reason", context.decision_reason
    assert_nil context.permission_suggestions
    assert_nil context.blocked_path
    assert_nil context.agent_id
  end
end
