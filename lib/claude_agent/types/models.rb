# frozen_string_literal: true

module ClaudeAgent
  # Return type for supported_models() (TypeScript SDK parity)
  #
  # @example
  #   model = ModelInfo.new(value: "claude-3-opus", display_name: "Claude 3 Opus", description: "Most capable")
  #   model.value        # => "claude-3-opus"
  #   model.display_name # => "Claude 3 Opus"
  #
  ModelInfo = Data.define(:value, :display_name, :description, :supports_effort, :supported_effort_levels, :supports_adaptive_thinking, :supports_fast_mode, :supports_auto_mode) do
    def initialize(value:, display_name: nil, description: nil, supports_effort: nil, supported_effort_levels: nil, supports_adaptive_thinking: nil, supports_fast_mode: nil, supports_auto_mode: nil)
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

  # Return type for supported_agents() (TypeScript SDK v0.2.63 parity)
  #
  # @example
  #   agent = AgentInfo.new(name: "Explore", description: "Search agent", model: "haiku")
  #   agent.name         # => "Explore"
  #   agent.description  # => "Search agent"
  #
  AgentInfo = Data.define(:name, :description, :model) do
    def initialize(name:, description: nil, model: nil)
      super
    end
  end

  # Agent definition for custom subagents (TypeScript SDK parity)
  #
  # @example Basic agent
  #   agent = AgentDefinition.new(
  #     description: "Runs tests and reports results",
  #     prompt: "You are a test runner...",
  #     tools: ["Read", "Grep", "Glob", "Bash"],
  #     model: "haiku"
  #   )
  #
  # @example Agent with skills and max_turns
  #   agent = AgentDefinition.new(
  #     description: "Research agent with specialized skills",
  #     prompt: "You are a research expert...",
  #     skills: ["web-search", "summarization"],
  #     max_turns: 10
  #   )
  #
  AgentDefinition = Data.define(
    :description,
    :prompt,
    :tools,
    :disallowed_tools,
    :model,
    :mcp_servers,
    :critical_system_reminder,
    :skills,
    :max_turns
  ) do
    def initialize(
      description:,
      prompt:,
      tools: nil,
      disallowed_tools: nil,
      model: nil,
      mcp_servers: nil,
      critical_system_reminder: nil,
      skills: nil,
      max_turns: nil
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
      result[:skills] = skills if skills
      result[:maxTurns] = max_turns if max_turns
      result
    end
  end

  # Composite initialization result from supported_commands request (TypeScript SDK parity)
  #
  # @example
  #   result = InitializationResult.new(
  #     commands: [SlashCommand.new(name: "commit")],
  #     output_style: "default",
  #     available_output_styles: ["default", "concise"],
  #     models: [ModelInfo.new(value: "claude-sonnet")],
  #     account: AccountInfo.new(email: "user@example.com"),
  #     agents: [AgentInfo.new(name: "Explore")]
  #   )
  #
  InitializationResult = Data.define(:commands, :output_style, :available_output_styles, :models, :account, :agents, :fast_mode_state) do
    def initialize(commands: [], output_style: nil, available_output_styles: [], models: [], account: nil, agents: [], fast_mode_state: nil)
      super
    end
  end
end
