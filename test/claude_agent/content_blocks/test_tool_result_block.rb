# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentContentBlocksToolResultBlock < ActiveSupport::TestCase
  test "tool_result_block" do
    block = ClaudeAgent::ToolResultBlock.new(
      tool_use_id: "tool_123",
      content: "file contents here",
      is_error: false
    )
    assert_equal "tool_123", block.tool_use_id
    assert_equal "file contents here", block.content
    assert_equal false, block.is_error
    assert_equal :tool_result, block.type
  end

  test "tool_result_block_optional_fields" do
    block = ClaudeAgent::ToolResultBlock.new(tool_use_id: "tool_123")
    assert_nil block.content
    assert_nil block.is_error
  end
end
