# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentMCPTool < ActiveSupport::TestCase
  test "tool_creation" do
    tool = ClaudeAgent::MCP::Tool.new(
      name: "greet",
      description: "Greet a person"
    ) { |args| "Hello!" }

    assert_equal "greet", tool.name
    assert_equal "Greet a person", tool.description
  end

  test "tool_with_simple_schema" do
    tool = ClaudeAgent::MCP::Tool.new(
      name: "add",
      description: "Add numbers",
      schema: { a: Float, b: Float }
    ) { |args| args["a"] + args["b"] }

    schema = tool.schema
    assert_equal "object", schema[:type]
    assert_equal "number", schema[:properties][:a][:type]
    assert_equal "number", schema[:properties][:b][:type]
    assert_includes schema[:required], "a"
    assert_includes schema[:required], "b"
  end

  test "tool_with_json_schema" do
    json_schema = {
      type: "object",
      properties: {
        name: { type: "string" },
        age: { type: "integer" }
      },
      required: [ "name" ]
    }

    tool = ClaudeAgent::MCP::Tool.new(
      name: "create_user",
      description: "Create a user",
      schema: json_schema
    ) { |args| "Created" }

    # Should preserve JSON Schema as-is
    assert_equal "object", tool.schema[:type]
    assert_equal "string", tool.schema[:properties][:name][:type]
  end

  test "tool_call_returns_string" do
    tool = ClaudeAgent::MCP::Tool.new(
      name: "greet",
      description: "Greet"
    ) { |args| "Hello, #{args["name"]}!" }

    result = tool.call({ "name" => "World" })

    assert_equal false, result[:isError]
    assert_equal 1, result[:content].length
    assert_equal "text", result[:content][0][:type]
    assert_equal "Hello, World!", result[:content][0][:text]
  end

  test "tool_call_returns_hash_with_content" do
    tool = ClaudeAgent::MCP::Tool.new(
      name: "fancy",
      description: "Fancy"
    ) do |args|
      { content: [ { type: "text", text: "Custom content" } ] }
    end

    result = tool.call({})

    assert_equal [ { type: "text", text: "Custom content" } ], result[:content]
  end

  test "tool_call_handles_error" do
    tool = ClaudeAgent::MCP::Tool.new(
      name: "fail",
      description: "Always fails"
    ) { |args| raise "Something went wrong" }

    result = tool.call({})

    assert_equal true, result[:isError]
    assert_match(/Something went wrong/, result[:content][0][:text])
  end

  test "tool_call_returns_number" do
    tool = ClaudeAgent::MCP::Tool.new(
      name: "add",
      description: "Add",
      schema: { a: Float, b: Float }
    ) { |args| args["a"] + args["b"] }

    result = tool.call({ "a" => 2, "b" => 3 })

    assert_equal false, result[:isError]
    assert_equal "5", result[:content][0][:text]
  end

  test "to_mcp_definition" do
    tool = ClaudeAgent::MCP::Tool.new(
      name: "test",
      description: "Test tool",
      schema: { value: String }
    ) { |args| "ok" }

    definition = tool.to_mcp_definition

    assert_equal "test", definition[:name]
    assert_equal "Test tool", definition[:description]
    assert definition[:inputSchema]
  end

  test "type_conversions" do
    # Test various Ruby type conversions
    tool = ClaudeAgent::MCP::Tool.new(
      name: "types",
      description: "Test types",
      schema: {
        str: String,
        int: Integer,
        num: Float,
        bool: TrueClass,
        arr: Array,
        obj: Hash
      }
    ) { |_| "ok" }

    props = tool.schema[:properties]
    assert_equal "string", props[:str][:type]
    assert_equal "integer", props[:int][:type]
    assert_equal "number", props[:num][:type]
    assert_equal "boolean", props[:bool][:type]
    assert_equal "array", props[:arr][:type]
    assert_equal "object", props[:obj][:type]
  end
end
