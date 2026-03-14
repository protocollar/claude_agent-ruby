# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentContentBlocksGenericBlock < ActiveSupport::TestCase
  test "generic_block" do
    block = ClaudeAgent::GenericBlock.new(
      block_type: "citation",
      raw: { text: "ref", url: "https://example.com" }
    )
    assert_equal "citation", block.block_type
    assert_equal :citation, block.type
    assert_equal({ text: "ref", url: "https://example.com" }, block.to_h)
  end

  test "generic_block_bracket_access" do
    block = ClaudeAgent::GenericBlock.new(
      block_type: "citation",
      raw: { text: "ref" }
    )
    assert_equal "ref", block[:text]
  end

  test "generic_block_method_missing" do
    block = ClaudeAgent::GenericBlock.new(
      block_type: "citation",
      raw: { text: "ref", url: "https://example.com" }
    )
    assert_equal "ref", block.text
    assert_equal "https://example.com", block.url
  end

  test "generic_block_respond_to_missing" do
    block = ClaudeAgent::GenericBlock.new(
      block_type: "citation",
      raw: { text: "ref" }
    )
    assert block.respond_to?(:text)
    refute block.respond_to?(:nonexistent)
  end

  test "generic_block_nil_type" do
    block = ClaudeAgent::GenericBlock.new(block_type: nil, raw: {})
    assert_equal :unknown, block.type
  end

  test "generic_block_in_types_constant" do
    assert_includes ClaudeAgent::CONTENT_BLOCK_TYPES, ClaudeAgent::GenericBlock
  end
end
