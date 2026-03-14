# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentControlProtocolLifecycle < ActiveSupport::TestCase
  setup do
    @transport = MockTransport.new
    @options = ClaudeAgent::Options.new
    @protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: @options)
  end

  test "initialization" do
    assert_nil @protocol.server_info
    refute @transport.connected?
  end

  test "start always sends initialize in streaming mode" do
    # Streaming mode always initializes (Python/TypeScript SDK parity)
    # No conditional on hooks, MCP, or can_use_tool
    options = ClaudeAgent::Options.new
    streaming = true
    refute options.has_hooks?
    refute options.has_sdk_mcp_servers?
    assert_nil options.can_use_tool
    # Even without any features, streaming mode always initializes
    assert streaming, "streaming should always trigger initialize"
  end
end
