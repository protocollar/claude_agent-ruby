# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentContentBlocksThinkingBlock < ActiveSupport::TestCase
  test "thinking_block" do
    block = ClaudeAgent::ThinkingBlock.new(thinking: "Let me think...", signature: "sig123")
    assert_equal "Let me think...", block.thinking
    assert_equal "sig123", block.signature
    assert_equal :thinking, block.type
    assert_equal({ type: "thinking", thinking: "Let me think...", signature: "sig123" }, block.to_h)
  end
end
