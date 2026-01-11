# frozen_string_literal: true

require_relative "../integration_helper"

class TestIntegrationMcp < IntegrationTestCase
  test "MCP tool definition" do
    tool = ClaudeAgent::MCP::Tool.new(
      name: "add",
      description: "Add two numbers",
      schema: { a: Float, b: Float }
    ) { |args| args["a"] + args["b"] }

    assert_equal "add", tool.name
    assert_equal "Add two numbers", tool.description

    schema = tool.schema
    assert_equal "object", schema[:type]
    assert_equal "number", schema[:properties][:a][:type]
    assert_equal "number", schema[:properties][:b][:type]

    result = tool.call({ "a" => 2, "b" => 3 })
    assert_equal false, result[:isError]
    assert_equal "5", result[:content][0][:text]
  end

  test "MCP tool error handling" do
    tool = ClaudeAgent::MCP::Tool.new(
      name: "fail",
      description: "Always fails"
    ) { |_| raise "Intentional error" }

    result = tool.call({})
    assert_equal true, result[:isError]
    assert result[:content][0][:text].include?("Intentional error")
  end

  test "MCP server creation" do
    tool1 = ClaudeAgent::MCP::Tool.new(name: "t1", description: "Tool 1") { "ok" }
    tool2 = ClaudeAgent::MCP::Tool.new(name: "t2", description: "Tool 2") { "ok" }

    server = ClaudeAgent::MCP::Server.new(
      name: "test-server",
      tools: [ tool1, tool2 ]
    )

    assert_equal "test-server", server.name
    assert_equal 2, server.tools.size

    found = server.tools["t1"]
    assert_not_nil found
    assert_equal "t1", found.name

    response = server.handle_message({ "method" => "tools/list", "id" => 1 })
    assert_equal 2, response[:result][:tools].length
  end

  test "McpSetServersResult type" do
    result = ClaudeAgent::McpSetServersResult.new(
      added: [ "server1", "server2" ],
      removed: [ "old-server" ],
      errors: { "server3" => "Connection failed" }
    )

    assert_equal [ "server1", "server2" ], result.added
    assert_equal [ "old-server" ], result.removed
    assert_equal({ "server3" => "Connection failed" }, result.errors)

    default_result = ClaudeAgent::McpSetServersResult.new
    assert_equal [], default_result.added
    assert_equal [], default_result.removed
    assert_equal({}, default_result.errors)
  end
end
