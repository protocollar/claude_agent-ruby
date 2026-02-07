# frozen_string_literal: true

require_relative "../integration_helper"

class TestIntegrationCanUseTool < IntegrationTestCase
  # --- Query API with can_use_tool ---

  test "query with can_use_tool allow completes successfully" do
    options = test_options(
      permission_mode: "default",
      can_use_tool: ->(_name, _input, _context) {
        ClaudeAgent::PermissionResultAllow.new
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

  test "query with can_use_tool deny blocks tool" do
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
      prompt: "Reply with exactly: TEST",
      options: options
    ).to_a

    result = messages.find { |m| m.is_a?(ClaudeAgent::ResultMessage) }
    assert_not_nil result, "Expected ResultMessage"
  end

  # --- Client API with can_use_tool ---

  test "client with can_use_tool allow" do
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

  test "client with can_use_tool deny" do
    options = test_options(
      permission_mode: "default",
      can_use_tool: ->(name, _input, _context) {
        if name == "Bash"
          ClaudeAgent::PermissionResultDeny.new(
            message: "Bash blocked in test",
            interrupt: false
          )
        else
          ClaudeAgent::PermissionResultAllow.new
        end
      }
    )

    ClaudeAgent::Client.open(options: options) do |client|
      client.query("Reply with exactly: DENY_TEST")

      result = nil
      client.receive_response.each do |msg|
        result = msg if msg.is_a?(ClaudeAgent::ResultMessage)
        break if result
      end

      assert_not_nil result
    end
  end

  # --- Options auto-configuration ---

  test "can_use_tool auto-sets permission_prompt_tool_name to stdio" do
    callback = ->(_name, _input, _context) { ClaudeAgent::PermissionResultAllow.new }
    options = ClaudeAgent::Options.new(can_use_tool: callback)

    assert_equal "stdio", options.permission_prompt_tool_name
    args = options.to_cli_args
    assert_includes args, "--permission-prompt-tool"
    idx = args.index("--permission-prompt-tool")
    assert_equal "stdio", args[idx + 1]
  end

  test "can_use_tool does not override explicit permission_prompt_tool_name" do
    callback = ->(_name, _input, _context) { ClaudeAgent::PermissionResultAllow.new }
    options = ClaudeAgent::Options.new(
      can_use_tool: callback,
      permission_prompt_tool_name: "custom"
    )

    assert_equal "custom", options.permission_prompt_tool_name
  end
end
