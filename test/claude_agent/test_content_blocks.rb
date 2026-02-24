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

  # --- ToolUseBlock#file_path ---

  test "tool_use_block file_path for Read" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "Read", input: { file_path: "/home/user/app/lib/foo.rb" })
    assert_equal "/home/user/app/lib/foo.rb", block.file_path
  end

  test "tool_use_block file_path for Write" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "Write", input: { file_path: "/tmp/out.txt", content: "hello" })
    assert_equal "/tmp/out.txt", block.file_path
  end

  test "tool_use_block file_path for Edit" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "Edit", input: { file_path: "/a/b.rb", old_string: "x", new_string: "y" })
    assert_equal "/a/b.rb", block.file_path
  end

  test "tool_use_block file_path for NotebookEdit" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "NotebookEdit", input: { notebook_path: "/nb/test.ipynb" })
    assert_equal "/nb/test.ipynb", block.file_path
  end

  test "tool_use_block file_path for Bash returns nil" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "Bash", input: { command: "ls" })
    assert_nil block.file_path
  end

  # --- ToolUseBlock#display_label ---

  test "tool_use_block display_label for Read shortens path" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "Read", input: { file_path: "/home/user/app/lib/foo.rb" })
    assert_equal "Read lib/foo.rb", block.display_label
  end

  test "tool_use_block display_label for short path" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "Read", input: { file_path: "foo.rb" })
    assert_equal "Read foo.rb", block.display_label
  end

  test "tool_use_block display_label for Bash truncates long command" do
    long_cmd = "a" * 80
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "Bash", input: { command: long_cmd })
    assert_equal "Bash: #{"a" * 50}...", block.display_label
  end

  test "tool_use_block display_label for Bash short command" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "Bash", input: { command: "git status" })
    assert_equal "Bash: git status", block.display_label
  end

  test "tool_use_block display_label for Grep" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "Grep", input: { pattern: "def foo" })
    assert_equal "Grep: def foo", block.display_label
  end

  test "tool_use_block display_label for Glob" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "Glob", input: { pattern: "**/*.rb" })
    assert_equal "Glob: **/*.rb", block.display_label
  end

  test "tool_use_block display_label for WebFetch extracts host" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "WebFetch", input: { url: "https://example.com/page" })
    assert_equal "WebFetch: example.com", block.display_label
  end

  test "tool_use_block display_label for WebFetch with invalid url" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "WebFetch", input: { url: "not a url %%%" })
    assert_equal "WebFetch", block.display_label
  end

  test "tool_use_block display_label for WebSearch" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "WebSearch", input: { query: "ruby data define" })
    assert_equal "WebSearch: ruby data define", block.display_label
  end

  test "tool_use_block display_label for Task" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "Task", input: { description: "explore codebase" })
    assert_equal "Task: explore codebase", block.display_label
  end

  test "tool_use_block display_label for unknown tool" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "CustomTool", input: { foo: "bar" })
    assert_equal "CustomTool", block.display_label
  end

  test "tool_use_block display_label for file tool with nil path" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "Read", input: {})
    assert_equal "Read", block.display_label
  end

  # --- ToolUseBlock#summary ---

  test "tool_use_block summary for Read" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "Read", input: { file_path: "/app/lib/foo.rb" })
    assert_equal "Read: /app/lib/foo.rb", block.summary
  end

  test "tool_use_block summary for Write with content" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "Write", input: { file_path: "/a/b.rb", content: "line1\nline2\nline3" })
    assert_equal "Write: /a/b.rb (3 lines)", block.summary
  end

  test "tool_use_block summary for Write with single line" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "Write", input: { file_path: "/a/b.rb", content: "hello" })
    assert_equal "Write: /a/b.rb (1 line)", block.summary
  end

  test "tool_use_block summary for Write with empty content" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "Write", input: { file_path: "/a/b.rb", content: "" })
    assert_equal "Write: /a/b.rb (empty)", block.summary
  end

  test "tool_use_block summary for Write with nil content" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "Write", input: { file_path: "/a/b.rb" })
    assert_equal "Write: /a/b.rb (empty)", block.summary
  end

  test "tool_use_block summary for Edit" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "Edit", input: { file_path: "/a/b.rb", old_string: "foo\nbar", new_string: "baz" })
    assert_equal "Edit: /a/b.rb replacing 2 line(s)", block.summary
  end

  test "tool_use_block summary for Edit single line" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "Edit", input: { file_path: "/a/b.rb", old_string: "foo", new_string: "bar" })
    assert_equal "Edit: /a/b.rb replacing 1 line(s)", block.summary
  end

  test "tool_use_block summary for Bash" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "Bash", input: { command: "git status" })
    assert_equal "Bash: git status", block.summary
  end

  test "tool_use_block summary for Grep with path and glob" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "Grep", input: { pattern: "def foo", path: "/app", glob: "*.rb" })
    assert_equal "Grep: def foo in /app (*.rb)", block.summary
  end

  test "tool_use_block summary for Grep pattern only" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "Grep", input: { pattern: "TODO" })
    assert_equal "Grep: TODO", block.summary
  end

  test "tool_use_block summary for unknown tool" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "CustomTool", input: { a: 1 })
    assert_includes block.summary, "CustomTool:"
  end

  test "tool_use_block summary truncation" do
    long_cmd = "a" * 100
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "Bash", input: { command: long_cmd })
    result = block.summary(max: 30)
    assert_equal 33, result.length # 30 + "..."
    assert result.end_with?("...")
  end

  test "tool_use_block summary custom max" do
    block = ClaudeAgent::ToolUseBlock.new(id: "1", name: "Read", input: { file_path: "/a/b.rb" })
    assert_equal "Read: /a/b.rb", block.summary(max: 100)
  end

  # --- ServerToolUseBlock#file_path ---

  test "server_tool_use_block file_path for Read" do
    block = ClaudeAgent::ServerToolUseBlock.new(id: "1", name: "Read", input: { file_path: "/a/b.rb" }, server_name: "fs")
    assert_equal "/a/b.rb", block.file_path
  end

  test "server_tool_use_block file_path for unknown returns nil" do
    block = ClaudeAgent::ServerToolUseBlock.new(id: "1", name: "query", input: { sql: "SELECT 1" }, server_name: "db")
    assert_nil block.file_path
  end

  # --- ServerToolUseBlock#display_label ---

  test "server_tool_use_block display_label with server" do
    block = ClaudeAgent::ServerToolUseBlock.new(id: "1", name: "fetch", input: {}, server_name: "web_server")
    assert_equal "web_server/fetch", block.display_label
  end

  test "server_tool_use_block display_label without server" do
    block = ClaudeAgent::ServerToolUseBlock.new(id: "1", name: "fetch", input: {}, server_name: nil)
    assert_equal "fetch", block.display_label
  end

  # --- ServerToolUseBlock#summary ---

  test "server_tool_use_block summary includes server and input" do
    block = ClaudeAgent::ServerToolUseBlock.new(id: "1", name: "query", input: { sql: "SELECT 1" }, server_name: "db")
    result = block.summary
    assert result.start_with?("db/query:")
  end

  test "server_tool_use_block summary truncation" do
    block = ClaudeAgent::ServerToolUseBlock.new(id: "1", name: "fetch", input: { url: "https://example.com/very/long/path/that/goes/on" }, server_name: "web")
    result = block.summary(max: 30)
    assert_equal 33, result.length
    assert result.end_with?("...")
  end

  # --- GenericBlock ---

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
