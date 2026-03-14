# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentContentBlocksTextBlock < ActiveSupport::TestCase
  test "text_block" do
    block = ClaudeAgent::TextBlock.new(text: "Hello, world!")
    assert_equal "Hello, world!", block.text
    assert_equal :text, block.type
    assert_equal({ type: "text", text: "Hello, world!" }, block.to_h)
  end
end
