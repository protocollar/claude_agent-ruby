# frozen_string_literal: true

require_relative "../integration_helper"

class TestIntegrationPermissions < IntegrationTestCase
  test "permission result allow" do
    result = ClaudeAgent::PermissionResultAllow.new(
      updated_input: { modified: true }
    )

    assert_equal "allow", result.behavior
    h = result.to_h
    assert_equal "allow", h[:behavior]
    assert_equal({ modified: true }, h[:updatedInput])
  end

  test "permission result deny" do
    result = ClaudeAgent::PermissionResultDeny.new(
      message: "Not allowed",
      interrupt: true
    )

    assert_equal "deny", result.behavior
    assert_equal true, result.interrupt
    h = result.to_h
    assert_equal "deny", h[:behavior]
    assert_equal "Not allowed", h[:message]
  end

  test "permission update" do
    update = ClaudeAgent::PermissionUpdate.new(
      type: "addRules",
      rules: [ { tool_name: "Read", behavior: "allow" } ]
    )

    assert_equal "addRules", update.type
    h = update.to_h
    assert_equal "addRules", h[:type]
    assert h[:rules].first[:toolName] == "Read"
  end

  test "permission rule value" do
    rule = ClaudeAgent::PermissionRuleValue.new(
      tool_name: "Read",
      rule_content: "allow"
    )

    assert_equal "Read", rule.tool_name
    assert_equal "allow", rule.rule_content
  end

  test "PERMISSION_UPDATE_DESTINATIONS includes cliArg" do
    destinations = ClaudeAgent::PERMISSION_UPDATE_DESTINATIONS

    assert destinations.include?("userSettings")
    assert destinations.include?("projectSettings")
    assert destinations.include?("localSettings")
    assert destinations.include?("session")
    assert destinations.include?("cliArg")
    assert_equal 5, destinations.length
  end
end
