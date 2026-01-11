# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentContentBlocks < ActiveSupport::TestCase
  test "text_block" do
    block = ClaudeAgent::TextBlock.new(text: "Hello, world!")
    assert_equal "Hello, world!", block.text
    assert_equal :text, block.type
    assert_equal({ type: "text", text: "Hello, world!" }, block.to_h)
  end

  test "thinking_block" do
    block = ClaudeAgent::ThinkingBlock.new(thinking: "Let me think...", signature: "sig123")
    assert_equal "Let me think...", block.thinking
    assert_equal "sig123", block.signature
    assert_equal :thinking, block.type
    assert_equal({ type: "thinking", thinking: "Let me think...", signature: "sig123" }, block.to_h)
  end

  test "tool_use_block" do
    block = ClaudeAgent::ToolUseBlock.new(
      id: "tool_123",
      name: "Read",
      input: { file_path: "/tmp/file.txt" }
    )
    assert_equal "tool_123", block.id
    assert_equal "Read", block.name
    assert_equal({ file_path: "/tmp/file.txt" }, block.input)
    assert_equal :tool_use, block.type
  end

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

  test "server_tool_use_block" do
    block = ClaudeAgent::ServerToolUseBlock.new(
      id: "srv_tool_123",
      name: "fetch",
      input: { url: "https://example.com" },
      server_name: "web_server"
    )
    assert_equal "srv_tool_123", block.id
    assert_equal "fetch", block.name
    assert_equal "web_server", block.server_name
    assert_equal :server_tool_use, block.type
  end

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

  test "image_content_block_with_string_keys" do
    source = { "type" => "base64", "media_type" => "image/jpeg", "data" => "base64data" }
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
