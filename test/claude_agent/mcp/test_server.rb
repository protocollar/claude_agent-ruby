# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentMCPServer < ActiveSupport::TestCase
  setup do
    @greet_tool = ClaudeAgent::MCP::Tool.new(
      name: "greet",
      description: "Greet a person",
      schema: { name: String }
    ) { |args| "Hello, #{args["name"]}!" }

    @add_tool = ClaudeAgent::MCP::Tool.new(
      name: "add",
      description: "Add two numbers",
      schema: { a: Float, b: Float }
    ) { |args| (args["a"] + args["b"]).to_s }

    @server = ClaudeAgent::MCP::Server.new(
      name: "test_server",
      tools: [ @greet_tool, @add_tool ]
    )
  end

  test "server_creation" do
    assert_equal "test_server", @server.name
    assert_equal 2, @server.tools.length
  end

  test "add_tool" do
    new_tool = ClaudeAgent::MCP::Tool.new(
      name: "new",
      description: "New tool"
    ) { "new" }

    @server.add_tool(new_tool)
    assert_equal 3, @server.tools.length
    assert @server.tools["new"]
  end

  test "remove_tool" do
    removed = @server.remove_tool("greet")
    assert_equal @greet_tool, removed
    assert_equal 1, @server.tools.length
    refute @server.tools["greet"]
  end

  test "handle_initialize" do
    message = {
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "initialize",
      "params" => {}
    }

    response = @server.handle_message(message)

    assert_equal "2.0", response[:jsonrpc]
    assert_equal 1, response[:id]
    assert response[:result][:capabilities][:tools]
    assert_equal "test_server", response[:result][:serverInfo][:name]
  end

  test "handle_tools_list" do
    message = {
      "jsonrpc" => "2.0",
      "id" => 2,
      "method" => "tools/list",
      "params" => {}
    }

    response = @server.handle_message(message)

    assert_equal 2, response[:id]
    tools = response[:result][:tools]
    assert_equal 2, tools.length

    tool_names = tools.map { |t| t[:name] }
    assert_includes tool_names, "greet"
    assert_includes tool_names, "add"
  end

  test "handle_tools_call" do
    message = {
      "jsonrpc" => "2.0",
      "id" => 3,
      "method" => "tools/call",
      "params" => {
        "name" => "greet",
        "arguments" => { "name" => "World" }
      }
    }

    response = @server.handle_message(message)

    assert_equal 3, response[:id]
    assert_equal false, response[:result][:isError]
    assert_equal "Hello, World!", response[:result][:content][0][:text]
  end

  test "handle_tools_call_unknown_tool" do
    message = {
      "jsonrpc" => "2.0",
      "id" => 4,
      "method" => "tools/call",
      "params" => {
        "name" => "unknown",
        "arguments" => {}
      }
    }

    response = @server.handle_message(message)

    assert_equal true, response[:result][:isError]
    assert_match(/Unknown tool/, response[:result][:content][0][:text])
  end

  test "handle_unknown_method" do
    message = {
      "jsonrpc" => "2.0",
      "id" => 5,
      "method" => "unknown/method",
      "params" => {}
    }

    response = @server.handle_message(message)

    assert response[:error]
    assert_equal(-32601, response[:error][:code])
    assert_match(/Method not found/, response[:error][:message])
  end

  test "handle_notifications_initialized" do
    message = {
      "jsonrpc" => "2.0",
      "method" => "notifications/initialized",
      "params" => {}
    }

    response = @server.handle_message(message)

    # Notifications don't get responses
    assert_nil response
  end

  test "to_config" do
    config = @server.to_config

    assert_equal "sdk", config[:type]
    assert_equal "test_server", config[:name]
    assert_equal @server, config[:instance]
  end

  test "convenience_methods" do
    tool = ClaudeAgent::MCP.tool("test", "Test tool", { x: Integer }) { |args| args["x"] * 2 }
    assert_instance_of ClaudeAgent::MCP::Tool, tool

    server = ClaudeAgent::MCP.create_server(name: "convenience", tools: [ tool ])
    assert_instance_of ClaudeAgent::MCP::Server, server
    assert_equal "convenience", server.name
    assert_equal 1, server.tools.length
  end

  test "add_tool_with_numeric_calculation" do
    message = {
      "jsonrpc" => "2.0",
      "id" => 6,
      "method" => "tools/call",
      "params" => {
        "name" => "add",
        "arguments" => { "a" => 10.5, "b" => 4.5 }
      }
    }

    response = @server.handle_message(message)

    assert_equal false, response[:result][:isError]
    assert_equal "15.0", response[:result][:content][0][:text]
  end
end
