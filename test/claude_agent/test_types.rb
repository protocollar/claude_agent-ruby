# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentTypes < ActiveSupport::TestCase
  # --- ToolsPreset ---

  test "tools_preset" do
    preset = ClaudeAgent::ToolsPreset.new(preset: "claude_code")
    assert_equal "preset", preset.type
    assert_equal "claude_code", preset.preset
  end

  test "tools_preset_to_h" do
    preset = ClaudeAgent::ToolsPreset.new(preset: "claude_code")
    assert_equal({ type: "preset", preset: "claude_code" }, preset.to_h)
  end

  # --- SlashCommand ---

  test "slash_command" do
    cmd = ClaudeAgent::SlashCommand.new(
      name: "commit",
      description: "Create a commit",
      argument_hint: "[message]"
    )
    assert_equal "commit", cmd.name
    assert_equal "Create a commit", cmd.description
    assert_equal "[message]", cmd.argument_hint
  end

  test "slash_command_defaults" do
    cmd = ClaudeAgent::SlashCommand.new(name: "help")
    assert_nil cmd.description
    assert_nil cmd.argument_hint
  end

  # --- ModelInfo ---

  test "model_info" do
    model = ClaudeAgent::ModelInfo.new(
      value: "claude-3-opus",
      display_name: "Claude 3 Opus",
      description: "Most capable"
    )
    assert_equal "claude-3-opus", model.value
    assert_equal "Claude 3 Opus", model.display_name
    assert_equal "Most capable", model.description
  end

  test "model_info_defaults" do
    model = ClaudeAgent::ModelInfo.new(value: "claude-sonnet")
    assert_nil model.display_name
    assert_nil model.description
  end

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
  end

  # --- AccountInfo ---

  test "account_info" do
    info = ClaudeAgent::AccountInfo.new(
      email: "user@example.com",
      organization: "Acme Corp",
      subscription_type: "pro",
      token_source: "oauth",
      api_key_source: "user"
    )
    assert_equal "user@example.com", info.email
    assert_equal "Acme Corp", info.organization
    assert_equal "pro", info.subscription_type
    assert_equal "oauth", info.token_source
    assert_equal "user", info.api_key_source
  end

  test "account_info_defaults" do
    info = ClaudeAgent::AccountInfo.new
    assert_nil info.email
    assert_nil info.organization
    assert_nil info.subscription_type
  end

  # --- ModelUsage ---

  test "model_usage" do
    usage = ClaudeAgent::ModelUsage.new(
      input_tokens: 100,
      output_tokens: 50,
      cache_read_input_tokens: 10,
      cache_creation_input_tokens: 5,
      web_search_requests: 2,
      cost_usd: 0.01,
      context_window: 128000
    )
    assert_equal 100, usage.input_tokens
    assert_equal 50, usage.output_tokens
    assert_equal 10, usage.cache_read_input_tokens
    assert_equal 5, usage.cache_creation_input_tokens
    assert_equal 2, usage.web_search_requests
    assert_equal 0.01, usage.cost_usd
    assert_equal 128000, usage.context_window
  end

  test "model_usage_defaults" do
    usage = ClaudeAgent::ModelUsage.new
    assert_equal 0, usage.input_tokens
    assert_equal 0, usage.output_tokens
    assert_equal 0.0, usage.cost_usd
    assert_nil usage.context_window
  end

  # --- SDKPermissionDenial ---

  test "sdk_permission_denial" do
    denial = ClaudeAgent::SDKPermissionDenial.new(
      tool_name: "Write",
      tool_use_id: "tool-123",
      tool_input: { file_path: "/etc/passwd" }
    )
    assert_equal "Write", denial.tool_name
    assert_equal "tool-123", denial.tool_use_id
    assert_equal({ file_path: "/etc/passwd" }, denial.tool_input)
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

  # --- RewindFilesResult ---

  test "rewind_files_result" do
    result = ClaudeAgent::RewindFilesResult.new(
      can_rewind: true,
      files_changed: [ "src/foo.rb", "src/bar.rb" ],
      insertions: 10,
      deletions: 5
    )
    assert result.can_rewind
    assert_nil result.error
    assert_equal [ "src/foo.rb", "src/bar.rb" ], result.files_changed
    assert_equal 10, result.insertions
    assert_equal 5, result.deletions
  end

  test "rewind_files_result_with_error" do
    result = ClaudeAgent::RewindFilesResult.new(
      can_rewind: false,
      error: "No checkpoint found"
    )
    refute result.can_rewind
    assert_equal "No checkpoint found", result.error
    assert_nil result.files_changed
    assert_nil result.insertions
    assert_nil result.deletions
  end

  # --- AgentDefinition ---

  test "agent_definition" do
    agent = ClaudeAgent::AgentDefinition.new(
      description: "Runs tests and reports results",
      prompt: "You are a test runner...",
      tools: [ "Read", "Grep", "Glob", "Bash" ],
      disallowed_tools: [ "Write" ],
      model: "haiku",
      mcp_servers: { "test-server" => { type: "stdio", command: "node" } },
      critical_system_reminder: "Always run tests safely"
    )
    assert_equal "Runs tests and reports results", agent.description
    assert_equal "You are a test runner...", agent.prompt
    assert_equal [ "Read", "Grep", "Glob", "Bash" ], agent.tools
    assert_equal [ "Write" ], agent.disallowed_tools
    assert_equal "haiku", agent.model
    assert_equal({ "test-server" => { type: "stdio", command: "node" } }, agent.mcp_servers)
    assert_equal "Always run tests safely", agent.critical_system_reminder
  end

  test "agent_definition_minimal" do
    agent = ClaudeAgent::AgentDefinition.new(
      description: "Simple agent",
      prompt: "You help with tasks"
    )
    assert_equal "Simple agent", agent.description
    assert_equal "You help with tasks", agent.prompt
    assert_nil agent.tools
    assert_nil agent.disallowed_tools
    assert_nil agent.model
    assert_nil agent.mcp_servers
    assert_nil agent.critical_system_reminder
  end

  test "agent_definition_to_h" do
    agent = ClaudeAgent::AgentDefinition.new(
      description: "Test runner",
      prompt: "Run tests",
      tools: [ "Bash" ],
      disallowed_tools: [ "Write" ],
      model: "haiku",
      mcp_servers: { "srv" => {} },
      critical_system_reminder: "Be careful"
    )
    h = agent.to_h
    assert_equal "Test runner", h[:description]
    assert_equal "Run tests", h[:prompt]
    assert_equal [ "Bash" ], h[:tools]
    assert_equal [ "Write" ], h[:disallowedTools]
    assert_equal "haiku", h[:model]
    assert_equal({ "srv" => {} }, h[:mcpServers])
    assert_equal "Be careful", h[:criticalSystemReminder_EXPERIMENTAL]
  end

  test "agent_definition_to_h_minimal" do
    agent = ClaudeAgent::AgentDefinition.new(
      description: "Simple agent",
      prompt: "You help"
    )
    h = agent.to_h
    assert_equal({ description: "Simple agent", prompt: "You help" }, h)
    refute h.key?(:tools)
    refute h.key?(:disallowedTools)
    refute h.key?(:model)
    refute h.key?(:mcpServers)
    refute h.key?(:criticalSystemReminder_EXPERIMENTAL)
  end

  # --- API Key Sources ---

  test "api_key_sources_constant" do
    assert_includes ClaudeAgent::API_KEY_SOURCES, "user"
    assert_includes ClaudeAgent::API_KEY_SOURCES, "project"
    assert_includes ClaudeAgent::API_KEY_SOURCES, "org"
    assert_includes ClaudeAgent::API_KEY_SOURCES, "temporary"
  end

  # --- Assistant Message Error Types ---

  test "assistant_message_error_types_constant" do
    assert_includes ClaudeAgent::ASSISTANT_MESSAGE_ERROR_TYPES, "authentication_failed"
    assert_includes ClaudeAgent::ASSISTANT_MESSAGE_ERROR_TYPES, "rate_limit"
    assert_includes ClaudeAgent::ASSISTANT_MESSAGE_ERROR_TYPES, "server_error"
  end
end
