# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentTypesMcp < ActiveSupport::TestCase
  # --- McpServerStatus ---

  test "mcp_server_status" do
    status = ClaudeAgent::McpServerStatus.new(
      name: "filesystem",
      status: "connected",
      server_info: { name: "fs", version: "1.0" }
    )
    assert_equal "filesystem", status.name
    assert_equal "connected", status.status
    assert_equal({ name: "fs", version: "1.0" }, status.server_info)
  end

  test "mcp_server_status_defaults" do
    status = ClaudeAgent::McpServerStatus.new(name: "test", status: "pending")
    assert_nil status.server_info
    assert_nil status.error
    assert_nil status.config
    assert_nil status.scope
    assert_nil status.tools
  end

  test "mcp_server_status_with_new_fields" do
    tools = [ { "name" => "read", "description" => "Read a file" } ]
    status = ClaudeAgent::McpServerStatus.new(
      name: "filesystem",
      status: "failed",
      error: "Connection refused",
      config: { "command" => "node", "args" => [ "server.js" ] },
      scope: "project",
      tools: tools
    )
    assert_equal "Connection refused", status.error
    assert_equal({ "command" => "node", "args" => [ "server.js" ] }, status.config)
    assert_equal "project", status.scope
    assert_equal tools, status.tools
  end

  # --- McpSetServersResult ---

  test "mcp_set_servers_result" do
    result = ClaudeAgent::McpSetServersResult.new(
      added: [ "server1", "server2" ],
      removed: [ "old-server" ],
      errors: { "server3" => "Connection failed" }
    )
    assert_equal [ "server1", "server2" ], result.added
    assert_equal [ "old-server" ], result.removed
    assert_equal({ "server3" => "Connection failed" }, result.errors)
  end

  test "mcp_set_servers_result_defaults" do
    result = ClaudeAgent::McpSetServersResult.new
    assert_equal [], result.added
    assert_equal [], result.removed
    assert_equal({}, result.errors)
  end
end
