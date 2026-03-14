# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentContentBlocksServerToolUseBlock < ActiveSupport::TestCase
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
end
