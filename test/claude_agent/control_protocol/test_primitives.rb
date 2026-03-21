# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentControlProtocolPrimitives < ActiveSupport::TestCase
  setup do
    @transport = MockTransport.new
    @options = ClaudeAgent::Options.new
    @protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: @options)
  end

  test "generate request id" do
    id1 = @protocol.send(:generate_request_id)
    id2 = @protocol.send(:generate_request_id)

    assert_match(/^req_\d+_[a-f0-9]+$/, id1)
    assert_match(/^req_\d+_[a-f0-9]+$/, id2)
    refute_equal id1, id2
  end

  test "build hooks config" do
    options = ClaudeAgent::Options.new(
      hooks: {
        "PreToolUse" => [
          ClaudeAgent::PreToolUseHook.new(
            matcher: "Bash|Write",
            callbacks: [ ->(i, c) { {} } ],
            timeout: 30
          )
        ],
        "PostToolUse" => [
          ClaudeAgent::PostToolUseHook.new(
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

  test "sdk_mcp_server_names extracts SDK server names" do
    options = ClaudeAgent::Options.new(
      mcp_servers: {
        "my-sdk-server" => { type: "sdk", instance: nil },
        "other-server" => { type: "stdio", command: "node" },
        "another-sdk" => { type: "sdk", instance: nil }
      }
    )
    protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: options)

    names = protocol.send(:sdk_mcp_server_names)
    assert_includes names, "my-sdk-server"
    assert_includes names, "another-sdk"
    refute_includes names, "other-server"
    assert_equal 2, names.length
  end

  test "send_initialize includes sdkMcpServers when SDK servers configured" do
    options = ClaudeAgent::Options.new(
      mcp_servers: {
        "my-sdk-server" => { type: "sdk", instance: nil }
      }
    )
    protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: options)

    protocol.start(streaming: true)
    protocol.stop

    msg = @transport.written_messages.find { |m| m["type"] == "control_request" && m["request"]["subtype"] == "initialize" }
    assert_not_nil msg
    assert_equal [ "my-sdk-server" ], msg["request"]["sdkMcpServers"]
  end

  test "send_initialize omits sdkMcpServers when no SDK servers" do
    options = ClaudeAgent::Options.new
    protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: options)

    protocol.start(streaming: true)
    protocol.stop

    msg = @transport.written_messages.find { |m| m["type"] == "control_request" && m["request"]["subtype"] == "initialize" }
    assert_not_nil msg
    refute msg["request"].key?("sdkMcpServers"), "Should not include sdkMcpServers when no SDK servers configured"
  end
end
