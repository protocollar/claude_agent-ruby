# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentContentBlocksServerToolResultBlock < ActiveSupport::TestCase
  test "server_tool_result_block" do
    block = ClaudeAgent::ServerToolResultBlock.new(
      tool_use_id: "srv_tool_123",
      server_name: "web_server",
      content: "response data"
    )
    assert_equal "srv_tool_123", block.tool_use_id
    assert_equal "web_server", block.server_name
    assert_equal "response data", block.content
    assert_equal :server_tool_result, block.type
  end
end
