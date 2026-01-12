# frozen_string_literal: true

module ClaudeAgent
  # Assistant message error types (TypeScript SDK parity)
  # Used to categorize errors returned by the assistant
  ASSISTANT_MESSAGE_ERROR_TYPES = %w[
    authentication_failed
    billing_error
    rate_limit
    invalid_request
    server_error
    unknown
  ].freeze

  # API key source types (TypeScript SDK parity)
  # Indicates where the API key was sourced from
  API_KEY_SOURCES = %w[user project org temporary].freeze

  # Tools preset configuration (TypeScript SDK parity)
  #
  # @example
  #   preset = ToolsPreset.new(preset: "claude_code")
  #   options = ClaudeAgent::Options.new(tools: preset)
  #
  ToolsPreset = Data.define(:type, :preset) do
    def initialize(type: "preset", preset: "claude_code")
      super
    end

    def to_h
      { type: type, preset: preset }
    end
  end
  # Return type for supported_commands() (TypeScript SDK parity)
  #
  # @example
  #   cmd = SlashCommand.new(name: "commit", description: "Create a commit", argument_hint: "[message]")
  #   cmd.name        # => "commit"
  #   cmd.description # => "Create a commit"
  #
  SlashCommand = Data.define(:name, :description, :argument_hint) do
    def initialize(name:, description: nil, argument_hint: nil)
      super
    end
  end

  # Return type for supported_models() (TypeScript SDK parity)
  #
  # @example
  #   model = ModelInfo.new(value: "claude-3-opus", display_name: "Claude 3 Opus", description: "Most capable")
  #   model.value        # => "claude-3-opus"
  #   model.display_name # => "Claude 3 Opus"
  #
  ModelInfo = Data.define(:value, :display_name, :description) do
    def initialize(value:, display_name: nil, description: nil)
      super
    end
  end

  # Return type for mcp_server_status() (TypeScript SDK parity)
  # Status values: "connected", "failed", "needs-auth", "pending"
  #
  # @example
  #   status = McpServerStatus.new(name: "filesystem", status: "connected", server_info: {name: "fs", version: "1.0"})
  #
  McpServerStatus = Data.define(:name, :status, :server_info) do
    def initialize(name:, status:, server_info: nil)
      super
    end
  end

  # Return type for account_info() (TypeScript SDK parity)
  #
  # @example
  #   info = AccountInfo.new(email: "user@example.com", organization: "Acme Corp")
  #
  AccountInfo = Data.define(:email, :organization, :subscription_type, :token_source, :api_key_source) do
    def initialize(email: nil, organization: nil, subscription_type: nil, token_source: nil, api_key_source: nil)
      super
    end
  end

  # Per-model usage statistics returned in result messages (TypeScript SDK parity)
  #
  # @example
  #   usage = ModelUsage.new(input_tokens: 100, output_tokens: 50, cost_usd: 0.01, max_output_tokens: 4096)
  #
  ModelUsage = Data.define(
    :input_tokens,
    :output_tokens,
    :cache_read_input_tokens,
    :cache_creation_input_tokens,
    :web_search_requests,
    :cost_usd,
    :context_window,
    :max_output_tokens
  ) do
    def initialize(
      input_tokens: 0,
      output_tokens: 0,
      cache_read_input_tokens: 0,
      cache_creation_input_tokens: 0,
      web_search_requests: 0,
      cost_usd: 0.0,
      context_window: nil,
      max_output_tokens: nil
    )
      super
    end
  end

  # Permission denial information in result messages (TypeScript SDK parity)
  #
  SDKPermissionDenial = Data.define(:tool_name, :tool_use_id, :tool_input) do
    def initialize(tool_name:, tool_use_id:, tool_input:)
      super
    end
  end

  # Result of set_mcp_servers() control method (TypeScript SDK parity)
  #
  # @example
  #   result = McpSetServersResult.new(
  #     added: ["server1"],
  #     removed: ["old-server"],
  #     errors: {"server2" => "Connection failed"}
  #   )
  #
  McpSetServersResult = Data.define(:added, :removed, :errors) do
    def initialize(added: [], removed: [], errors: {})
      super
    end
  end

  # Result of rewind_files() control method (TypeScript SDK parity)
  #
  # @example
  #   result = RewindFilesResult.new(
  #     can_rewind: true,
  #     files_changed: ["src/foo.rb", "src/bar.rb"],
  #     insertions: 10,
  #     deletions: 5
  #   )
  #
  RewindFilesResult = Data.define(:can_rewind, :error, :files_changed, :insertions, :deletions) do
    def initialize(can_rewind:, error: nil, files_changed: nil, insertions: nil, deletions: nil)
      super
    end
  end

  # Agent definition for custom subagents (TypeScript SDK parity)
  #
  # @example
  #   agent = AgentDefinition.new(
  #     description: "Runs tests and reports results",
  #     prompt: "You are a test runner...",
  #     tools: ["Read", "Grep", "Glob", "Bash"],
  #     model: "haiku"
  #   )
  #
  AgentDefinition = Data.define(
    :description,
    :prompt,
    :tools,
    :disallowed_tools,
    :model,
    :mcp_servers,
    :critical_system_reminder
  ) do
    def initialize(
      description:,
      prompt:,
      tools: nil,
      disallowed_tools: nil,
      model: nil,
      mcp_servers: nil,
      critical_system_reminder: nil
    )
      super
    end

    def to_h
      result = {
        description: description,
        prompt: prompt
      }
      result[:tools] = tools if tools
      result[:disallowedTools] = disallowed_tools if disallowed_tools
      result[:model] = model if model
      result[:mcpServers] = mcp_servers if mcp_servers
      result[:criticalSystemReminder_EXPERIMENTAL] = critical_system_reminder if critical_system_reminder
      result
    end
  end
end
