# frozen_string_literal: true

require_relative "../integration_helper"

class TestIntegrationPermissionsAndToolsScenarios < IntegrationTestCase
  test "can_use_tool allow and deny via query" do
    denied_tools = []

    options = test_options(
      permission_mode: "default",
      can_use_tool: ->(name, _input, _context) {
        if name == "Write"
          denied_tools << name
          ClaudeAgent::PermissionResultDeny.new(message: "Write not allowed in test")
        else
          ClaudeAgent::PermissionResultAllow.new
        end
      }
    )

    messages = ClaudeAgent.query(
      prompt: "Reply with exactly: HELLO",
      options: options
    ).to_a

    result = messages.find { |m| m.is_a?(ClaudeAgent::ResultMessage) }
    assert_not_nil result, "Expected ResultMessage"
    assert_equal false, result.is_error
  end

  test "can_use_tool via client" do
    options = test_options(
      permission_mode: "default",
      can_use_tool: ->(_name, _input, _context) {
        ClaudeAgent::PermissionResultAllow.new
      }
    )

    ClaudeAgent::Client.open(options: options) do |client|
      client.query("Reply with exactly: CLIENT_TEST")

      result = nil
      client.receive_response.each do |msg|
        result = msg if msg.is_a?(ClaudeAgent::ResultMessage)
        break if result
      end

      assert_not_nil result
      assert_equal false, result.is_error
    end
  end

  test "tool activity tracker captures events" do
    started = []
    completed = []

    conversation = ClaudeAgent::Conversation.new(
      max_turns: 1,
      track_tools: true
    )
    conversation.tool_tracker.on_start { |entry| started << entry.name }
    conversation.tool_tracker.on_complete { |entry| completed << entry.name }

    conversation.say("Use the Bash tool to run: echo TRACKER_TEST")

    assert started.any?, "Expected at least one on_start callback"
    assert completed.any?, "Expected at least one on_complete callback"

    # Tracker persists after say (resets at start of next say)
    refute conversation.tool_tracker.empty?, "Tracker should retain data after say returns"
  ensure
    conversation&.close
  end
end
