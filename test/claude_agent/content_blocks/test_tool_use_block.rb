# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentContentBlocksToolUseBlock < ActiveSupport::TestCase
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
end
