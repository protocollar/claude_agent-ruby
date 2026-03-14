# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentContentBlocksImageContentBlock < ActiveSupport::TestCase
  test "image content block with base64" do
    source = { type: "base64", media_type: "image/png", data: "iVBORw0KGgo..." }
    block = ClaudeAgent::ImageContentBlock.new(source: source)

    assert_equal :image, block.type
    assert_equal "base64", block.source_type
    assert_equal "image/png", block.media_type
    assert_equal "iVBORw0KGgo...", block.data
    assert_nil block.url
  end

  test "image_content_block_with_url" do
    source = { type: "url", url: "https://example.com/image.png" }
    block = ClaudeAgent::ImageContentBlock.new(source: source)

    assert_equal :image, block.type
    assert_equal "url", block.source_type
    assert_equal "https://example.com/image.png", block.url
    assert_nil block.media_type
    assert_nil block.data
  end

  test "image_content_block_with_symbol_keys" do
    source = { type: "base64", media_type: "image/jpeg", data: "base64data" }
    block = ClaudeAgent::ImageContentBlock.new(source: source)

    assert_equal "base64", block.source_type
    assert_equal "image/jpeg", block.media_type
    assert_equal "base64data", block.data
  end

  test "image_content_block_to_h" do
    source = { type: "base64", media_type: "image/png", data: "data" }
    block = ClaudeAgent::ImageContentBlock.new(source: source)

    expected = { type: "image", source: source }
    assert_equal expected, block.to_h
  end

  test "content_block_types_constant" do
    assert_includes ClaudeAgent::CONTENT_BLOCK_TYPES, ClaudeAgent::ImageContentBlock
  end
end
