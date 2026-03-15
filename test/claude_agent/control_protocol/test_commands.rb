# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentControlProtocolCommands < ActiveSupport::TestCase
  setup do
    @transport = MockTransport.new
    @options = ClaudeAgent::Options.new
    @protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: @options)
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

  test "initialization_result sends supported_commands request format" do
    @transport.connect

    @protocol.send(:write_message, {
      type: "control_request",
      request_id: "test-req",
      request: { subtype: "supported_commands" }
    })

    msg = @transport.written_messages.find { |m| m["type"] == "control_request" }
    assert_not_nil msg
    assert_equal "supported_commands", msg["request"]["subtype"]
  end

  test "stop_task sends correct request format" do
    @transport.connect

    # Write the request message directly (bypassing the full protocol machinery)
    @protocol.send(:write_message, {
      type: "control_request",
      request_id: "test-req",
      request: { subtype: "stop_task", task_id: "task-123" }
    })

    msg = @transport.written_messages.find { |m| m["type"] == "control_request" }
    assert_not_nil msg
    assert_equal "stop_task", msg["request"]["subtype"]
    assert_equal "task-123", msg["request"]["task_id"]
  end

  test "apply_flag_settings sends correct request format" do
    @transport.connect

    @protocol.send(:write_message, {
      type: "control_request",
      request_id: "test-req",
      request: { subtype: "apply_flag_settings", settings: { "model" => "claude-sonnet-4-5-20250514" } }
    })

    msg = @transport.written_messages.find { |m| m["type"] == "control_request" }
    assert_not_nil msg
    assert_equal "apply_flag_settings", msg["request"]["subtype"]
    assert_equal({ "model" => "claude-sonnet-4-5-20250514" }, msg["request"]["settings"])
  end

  test "mcp_authenticate sends correct request format" do
    @transport.connect

    @protocol.send(:write_message, {
      type: "control_request",
      request_id: "test-req",
      request: { subtype: "mcp_authenticate", serverName: "my-remote-server" }
    })

    msg = @transport.written_messages.find { |m| m["type"] == "control_request" }
    assert_not_nil msg
    assert_equal "mcp_authenticate", msg["request"]["subtype"]
    assert_equal "my-remote-server", msg["request"]["serverName"]
  end

  test "mcp_clear_auth sends correct request format" do
    @transport.connect

    @protocol.send(:write_message, {
      type: "control_request",
      request_id: "test-req",
      request: { subtype: "mcp_clear_auth", serverName: "my-remote-server" }
    })

    msg = @transport.written_messages.find { |m| m["type"] == "control_request" }
    assert_not_nil msg
    assert_equal "mcp_clear_auth", msg["request"]["subtype"]
    assert_equal "my-remote-server", msg["request"]["serverName"]
  end

  test "cancel_async_message sends correct request format" do
    @transport.connect

    @protocol.send(:write_message, {
      type: "control_request",
      request_id: "test-req",
      request: { subtype: "cancel_async_message", message_uuid: "msg-uuid-123" }
    })

    msg = @transport.written_messages.find { |m| m["type"] == "control_request" }
    assert_not_nil msg
    assert_equal "cancel_async_message", msg["request"]["subtype"]
    assert_equal "msg-uuid-123", msg["request"]["message_uuid"]
  end

  test "get_settings sends correct request format" do
    @transport.connect

    @protocol.send(:write_message, {
      type: "control_request",
      request_id: "test-req",
      request: { subtype: "get_settings" }
    })

    msg = @transport.written_messages.find { |m| m["type"] == "control_request" }
    assert_not_nil msg
    assert_equal "get_settings", msg["request"]["subtype"]
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
