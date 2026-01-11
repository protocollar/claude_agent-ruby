# frozen_string_literal: true

require_relative "../integration_helper"

class TestIntegrationTypes < IntegrationTestCase
  test "SlashCommand type" do
    cmd = ClaudeAgent::SlashCommand.new(
      name: "commit",
      description: "Commit changes",
      argument_hint: "[message]"
    )

    assert_equal "commit", cmd.name
    assert_equal "Commit changes", cmd.description
    assert_equal "[message]", cmd.argument_hint
  end

  test "ModelInfo type" do
    model = ClaudeAgent::ModelInfo.new(
      value: "claude-sonnet-4-5-20250514",
      display_name: "Claude Sonnet",
      description: "Fast and capable model"
    )

    assert_equal "claude-sonnet-4-5-20250514", model.value
    assert_equal "Claude Sonnet", model.display_name
    assert_equal "Fast and capable model", model.description
  end

  test "McpServerStatus type" do
    status = ClaudeAgent::McpServerStatus.new(
      name: "my-server",
      status: "connected",
      server_info: { version: "1.0.0" }
    )

    assert_equal "my-server", status.name
    assert_equal "connected", status.status
    assert_equal({ version: "1.0.0" }, status.server_info)
  end

  test "AccountInfo type" do
    info = ClaudeAgent::AccountInfo.new(
      email: "user@example.com",
      organization: "My Org",
      subscription_type: "pro",
      token_source: "anthropic",
      api_key_source: "env"
    )

    assert_equal "user@example.com", info.email
    assert_equal "My Org", info.organization
    assert_equal "pro", info.subscription_type
    assert_equal "anthropic", info.token_source
    assert_equal "env", info.api_key_source
  end

  test "ModelUsage type" do
    usage = ClaudeAgent::ModelUsage.new(
      input_tokens: 100,
      output_tokens: 200,
      cache_read_input_tokens: 50,
      cache_creation_input_tokens: 25,
      web_search_requests: 0,
      cost_usd: 0.005,
      context_window: 128000
    )

    assert_equal 100, usage.input_tokens
    assert_equal 200, usage.output_tokens
    assert_equal 50, usage.cache_read_input_tokens
    assert_equal 25, usage.cache_creation_input_tokens
    assert_equal 0, usage.web_search_requests
    assert_equal 0.005, usage.cost_usd
    assert_equal 128000, usage.context_window
  end

  test "SDKPermissionDenial type" do
    denial = ClaudeAgent::SDKPermissionDenial.new(
      tool_name: "Write",
      tool_use_id: "tool_123",
      tool_input: { file_path: "/etc/passwd" }
    )

    assert_equal "Write", denial.tool_name
    assert_equal "tool_123", denial.tool_use_id
    assert_equal({ file_path: "/etc/passwd" }, denial.tool_input)
  end

  test "ASSISTANT_MESSAGE_ERROR_TYPES enum" do
    enum = ClaudeAgent::ASSISTANT_MESSAGE_ERROR_TYPES

    assert enum.is_a?(Array), "Expected frozen array"
    assert enum.frozen?, "Expected frozen"
    assert enum.include?("authentication_failed")
    assert enum.include?("billing_error")
    assert enum.include?("rate_limit")
    assert enum.include?("invalid_request")
    assert enum.include?("server_error")
    assert enum.include?("unknown")
  end

  test "API_KEY_SOURCES enum" do
    enum = ClaudeAgent::API_KEY_SOURCES

    assert enum.is_a?(Array), "Expected frozen array"
    assert enum.frozen?, "Expected frozen"
    assert enum.include?("user")
    assert enum.include?("project")
    assert enum.include?("org")
    assert enum.include?("temporary")
  end

  test "ToolsPreset type" do
    preset = ClaudeAgent::ToolsPreset.new
    assert_equal "preset", preset.type
    assert_equal "claude_code", preset.preset

    custom = ClaudeAgent::ToolsPreset.new(preset: "custom_preset")
    assert_equal "preset", custom.type
    assert_equal "custom_preset", custom.preset

    h = preset.to_h
    assert_equal "preset", h[:type]
    assert_equal "claude_code", h[:preset]
  end

  test "ImageContentBlock type" do
    assert ClaudeAgent::CONTENT_BLOCK_TYPES.include?(ClaudeAgent::ImageContentBlock)

    source = { type: "base64", media_type: "image/png", data: "iVBORw0KGgo..." }
    block = ClaudeAgent::ImageContentBlock.new(source: source)

    assert_equal :image, block.type
    assert_equal "base64", block.source_type
    assert_equal "image/png", block.media_type
    assert_equal "iVBORw0KGgo...", block.data
    assert block.url.nil?, "Expected url to be nil for base64 source"

    url_source = { type: "url", url: "https://example.com/image.png" }
    url_block = ClaudeAgent::ImageContentBlock.new(source: url_source)

    assert_equal "url", url_block.source_type
    assert_equal "https://example.com/image.png", url_block.url
    assert url_block.media_type.nil?, "Expected media_type to be nil for URL source"

    h = block.to_h
    assert_equal "image", h[:type]
    assert_equal source, h[:source]
  end

  test "CompactBoundaryMessage type" do
    assert ClaudeAgent::MESSAGE_TYPES.include?(ClaudeAgent::CompactBoundaryMessage)

    msg = ClaudeAgent::CompactBoundaryMessage.new(
      uuid: "msg-123",
      session_id: "sess-abc",
      compact_metadata: { trigger: "auto", pre_tokens: 50000 }
    )

    assert_equal :compact_boundary, msg.type
    assert_equal "msg-123", msg.uuid
    assert_equal "sess-abc", msg.session_id
    assert_equal "auto", msg.trigger
    assert_equal 50000, msg.pre_tokens

    msg2 = ClaudeAgent::CompactBoundaryMessage.new(
      uuid: "msg-456",
      session_id: "sess-xyz",
      compact_metadata: { "trigger" => "manual", "pre_tokens" => 25000 }
    )

    assert_equal "manual", msg2.trigger
    assert_equal 25000, msg2.pre_tokens
  end

  test "AbortError type" do
    error = ClaudeAgent::AbortError.new
    assert_kind_of ClaudeAgent::Error, error
    assert error.message.include?("aborted")

    custom = ClaudeAgent::AbortError.new("User cancelled operation")
    assert_equal "User cancelled operation", custom.message
  end

  test "RewindFilesResult type" do
    result = ClaudeAgent::RewindFilesResult.new(
      can_rewind: true,
      files_changed: [ "src/foo.rb", "src/bar.rb" ],
      insertions: 10,
      deletions: 5
    )

    assert result.can_rewind
    assert_equal [ "src/foo.rb", "src/bar.rb" ], result.files_changed
    assert_equal 10, result.insertions
    assert_equal 5, result.deletions

    error_result = ClaudeAgent::RewindFilesResult.new(
      can_rewind: false,
      error: "No checkpoint found"
    )
    assert !error_result.can_rewind
    assert_equal "No checkpoint found", error_result.error
  end

  test "AgentDefinition type" do
    agent = ClaudeAgent::AgentDefinition.new(
      description: "Runs tests",
      prompt: "You are a test runner",
      tools: [ "Read", "Bash" ],
      disallowed_tools: [ "Write" ],
      model: "haiku",
      mcp_servers: { "test-server" => { type: "stdio" } },
      critical_system_reminder: "Run tests safely"
    )

    assert_equal "Runs tests", agent.description
    assert_equal "You are a test runner", agent.prompt
    assert_equal [ "Read", "Bash" ], agent.tools
    assert_equal [ "Write" ], agent.disallowed_tools
    assert_equal "haiku", agent.model
    assert_equal({ "test-server" => { type: "stdio" } }, agent.mcp_servers)
    assert_equal "Run tests safely", agent.critical_system_reminder

    h = agent.to_h
    assert_equal "Runs tests", h[:description]
    assert_equal [ "Write" ], h[:disallowedTools]
    assert_equal({ "test-server" => { type: "stdio" } }, h[:mcpServers])
    assert_equal "Run tests safely", h[:criticalSystemReminder_EXPERIMENTAL]
  end

  test "ToolPermissionContext new fields" do
    context = ClaudeAgent::ToolPermissionContext.new(
      permission_suggestions: [ { type: "addRules" } ],
      blocked_path: "/etc/passwd",
      decision_reason: "Path outside allowed directories",
      tool_use_id: "tool-123",
      agent_id: "agent-456"
    )

    assert_equal [ { type: "addRules" } ], context.permission_suggestions
    assert_equal "/etc/passwd", context.blocked_path
    assert_equal "Path outside allowed directories", context.decision_reason
    assert_equal "tool-123", context.tool_use_id
    assert_equal "agent-456", context.agent_id
  end

  test "SandboxNetworkConfig type" do
    config = ClaudeAgent::SandboxNetworkConfig.new(
      allow_local_binding: true,
      allow_unix_sockets: [ "/tmp/socket" ],
      allow_all_unix_sockets: false,
      http_proxy_port: 8080,
      socks_proxy_port: 1080
    )

    assert_equal true, config.allow_local_binding
    assert_equal [ "/tmp/socket" ], config.allow_unix_sockets
    assert_equal false, config.allow_all_unix_sockets
    assert_equal 8080, config.http_proxy_port
    assert_equal 1080, config.socks_proxy_port
  end

  test "SandboxIgnoreViolations type" do
    violations = ClaudeAgent::SandboxIgnoreViolations.new(
      file: [ "/tmp/*" ],
      network: [ "localhost:*" ]
    )

    assert_equal [ "/tmp/*" ], violations.file
    assert_equal [ "localhost:*" ], violations.network
  end

  test "SandboxSettings type" do
    network = ClaudeAgent::SandboxNetworkConfig.new(
      allow_local_binding: true
    )

    settings = ClaudeAgent::SandboxSettings.new(
      enabled: true,
      auto_allow_bash_if_sandboxed: true,
      excluded_commands: [ "rm" ],
      allow_unsandboxed_commands: false,
      network: network,
      enable_weaker_nested_sandbox: true
    )

    assert_equal true, settings.enabled
    assert_equal true, settings.auto_allow_bash_if_sandboxed
    assert_equal [ "rm" ], settings.excluded_commands
    assert_equal false, settings.allow_unsandboxed_commands
    assert_equal network, settings.network
    assert_equal true, settings.enable_weaker_nested_sandbox

    h = settings.to_h
    assert_equal true, h[:enabled]
    assert_equal true, h[:autoAllowBashIfSandboxed]
    assert_equal [ "rm" ], h[:excludedCommands]
  end

  test "SandboxRipgrepConfig type" do
    config = ClaudeAgent::SandboxRipgrepConfig.new(
      command: "/usr/local/bin/rg",
      args: [ "--hidden", "--follow" ]
    )

    assert_equal "/usr/local/bin/rg", config.command
    assert_equal [ "--hidden", "--follow" ], config.args

    h = config.to_h
    assert_equal "/usr/local/bin/rg", h[:command]
    assert_equal [ "--hidden", "--follow" ], h[:args]
  end

  test "SandboxNetworkConfig allowed_domains field" do
    config = ClaudeAgent::SandboxNetworkConfig.new(
      allowed_domains: [ "api.example.com", "github.com" ],
      allow_local_binding: true
    )

    assert_equal [ "api.example.com", "github.com" ], config.allowed_domains
    assert config.allow_local_binding

    h = config.to_h
    assert_equal [ "api.example.com", "github.com" ], h[:allowedDomains]
  end
end
