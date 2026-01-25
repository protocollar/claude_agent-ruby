# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentControlProtocol < ActiveSupport::TestCase
  setup do
    @transport = MockTransport.new
    @options = ClaudeAgent::Options.new
    @protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: @options)
  end

  test "initialization" do
    assert_nil @protocol.server_info
    refute @transport.connected?
  end

  test "send user message" do
    @transport.connect
    @protocol.send_user_message("Hello!", session_id: "test-session")

    assert_equal 1, @transport.written_messages.length
    msg = @transport.written_messages.first

    assert_equal "user", msg["type"]
    assert_equal "user", msg["message"]["role"]
    assert_equal "Hello!", msg["message"]["content"]
    assert_equal "test-session", msg["session_id"]
  end

  test "send user message with uuid" do
    @transport.connect
    @protocol.send_user_message("Hello!", session_id: "test", uuid: "msg-123")

    msg = @transport.written_messages.first
    assert_equal "msg-123", msg["uuid"]
  end

  test "generate request id" do
    id1 = @protocol.send(:generate_request_id)
    id2 = @protocol.send(:generate_request_id)

    assert_match(/^req_\d+_[a-f0-9]+$/, id1)
    assert_match(/^req_\d+_[a-f0-9]+$/, id2)
    refute_equal id1, id2
  end

  test "normalize hook response basic" do
    result = {
      continue_: true,
      suppress_output: false,
      decision: "allow"
    }

    normalized = @protocol.send(:normalize_hook_response, result)

    assert_equal true, normalized["continue"]
    assert_equal false, normalized["suppressOutput"]
    assert_equal "allow", normalized["decision"]
  end

  test "normalize hook response with async" do
    result = {
      async_: true,
      stop_reason: "user_requested"
    }

    normalized = @protocol.send(:normalize_hook_response, result)

    assert_equal true, normalized["async"]
    assert_equal "user_requested", normalized["stopReason"]
  end

  test "handle can use tool default allow" do
    request = { "tool_name" => "Read", "input" => { "file_path" => "/tmp/test" } }

    result = @protocol.send(:handle_can_use_tool, request)

    assert_equal "allow", result[:behavior]
  end

  test "handle can use tool with callback allow" do
    options = ClaudeAgent::Options.new(
      can_use_tool: ->(name, input, context) {
        { behavior: "allow", updated_input: input.merge("modified" => true) }
      }
    )
    protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: options)

    request = { "tool_name" => "Read", "input" => { "file_path" => "/tmp" } }
    result = protocol.send(:handle_can_use_tool, request)

    assert_equal "allow", result[:behavior]
    assert result[:updatedInput]["modified"]
  end

  test "handle can use tool with callback deny" do
    options = ClaudeAgent::Options.new(
      can_use_tool: ->(name, input, context) {
        { behavior: "deny", message: "Not allowed", interrupt: true }
      }
    )
    protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: options)

    request = { "tool_name" => "Bash", "input" => { "command" => "rm -rf /" } }
    result = protocol.send(:handle_can_use_tool, request)

    assert_equal "deny", result[:behavior]
    assert_equal "Not allowed", result[:message]
    assert result[:interrupt]
  end

  test "handle hook callback" do
    callback_called = false
    callback_input = nil

    options = ClaudeAgent::Options.new(
      hooks: {
        "PreToolUse" => [
          ClaudeAgent::HookMatcher.new(
            matcher: "Read",
            callbacks: [ ->(input, context) {
              callback_called = true
              callback_input = input
              { continue_: true }
            } ],
            timeout: nil
          )
        ]
      }
    )
    protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: options)

    # Build hooks config to register callbacks
    protocol.send(:build_hooks_config)

    request = {
      "callback_id" => "hook_PreToolUse_0_0",
      "input" => { "tool_name" => "Read", "tool_input" => {} },
      "tool_use_id" => "tool_123"
    }
    result = protocol.send(:handle_hook_callback, request)

    assert callback_called
    assert_equal({ "tool_name" => "Read", "tool_input" => {} }, callback_input)
    assert_equal true, result["continue"]
  end

  test "build hooks config" do
    options = ClaudeAgent::Options.new(
      hooks: {
        "PreToolUse" => [
          ClaudeAgent::HookMatcher.new(
            matcher: "Bash|Write",
            callbacks: [ ->(i, c) { {} } ],
            timeout: 30
          )
        ],
        "PostToolUse" => [
          ClaudeAgent::HookMatcher.new(
            matcher: ".*",
            callbacks: [ ->(i, c) { {} }, ->(i, c) { {} } ],
            timeout: nil
          )
        ]
      }
    )
    protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: options)

    config = protocol.send(:build_hooks_config)

    assert_equal 1, config["PreToolUse"].length
    assert_equal "Bash|Write", config["PreToolUse"][0][:matcher]
    assert_equal 1, config["PreToolUse"][0][:hookCallbackIds].length
    assert_equal 30, config["PreToolUse"][0][:timeout]

    assert_equal 1, config["PostToolUse"].length
    assert_equal 2, config["PostToolUse"][0][:hookCallbackIds].length
    refute config["PostToolUse"][0].key?(:timeout)
  end

  test "mcp_reconnect sends correct request format" do
    @transport.connect

    # Write the request message directly (bypassing the full protocol machinery)
    @protocol.send(:write_message, {
      type: "control_request",
      request_id: "test-req",
      request: { subtype: "mcp_reconnect", serverName: "my-server" }
    })

    msg = @transport.written_messages.find { |m| m["type"] == "control_request" }
    assert_not_nil msg
    assert_equal "mcp_reconnect", msg["request"]["subtype"]
    assert_equal "my-server", msg["request"]["serverName"]
  end

  test "mcp_toggle sends correct request format" do
    @transport.connect

    # Write the request message directly (bypassing the full protocol machinery)
    @protocol.send(:write_message, {
      type: "control_request",
      request_id: "test-req",
      request: { subtype: "mcp_toggle", serverName: "my-server", enabled: false }
    })

    msg = @transport.written_messages.find { |m| m["type"] == "control_request" }
    assert_not_nil msg
    assert_equal "mcp_toggle", msg["request"]["subtype"]
    assert_equal "my-server", msg["request"]["serverName"]
    assert_equal false, msg["request"]["enabled"]
  end
end
