# frozen_string_literal: true

module ClaudeAgent
  # Return type for supported_models() (TypeScript SDK parity)
  #
  # @example
  #   model = ModelInfo.new(value: "claude-3-opus", display_name: "Claude 3 Opus", description: "Most capable")
  #   model.value        # => "claude-3-opus"
  #   model.display_name # => "Claude 3 Opus"
  #
  class ModelInfo < ImmutableRecord
    attribute :value
    attribute :display_name, default: nil
    attribute :description, default: nil
    attribute :supports_effort, default: nil
    attribute :supported_effort_levels, default: nil
    attribute :supports_adaptive_thinking, default: nil
    attribute :supports_fast_mode, default: nil
    attribute :supports_auto_mode, default: nil
  end

  # Per-model usage statistics returned in result messages (TypeScript SDK parity)
  #
  # @example
  #   usage = ModelUsage.new(input_tokens: 100, output_tokens: 50, cost_usd: 0.01, max_output_tokens: 4096)
  #
  class ModelUsage < ImmutableRecord
    attribute :input_tokens, default: 0
    attribute :output_tokens, default: 0
    attribute :cache_read_input_tokens, default: 0
    attribute :cache_creation_input_tokens, default: 0
    attribute :web_search_requests, default: 0
    attribute :cost_usd, default: 0.0
    attribute :context_window, default: nil
    attribute :max_output_tokens, default: nil
  end

  # Return type for account_info() (TypeScript SDK parity)
  #
  # @example
  #   info = AccountInfo.new(email: "user@example.com", organization: "Acme Corp")
  #
  class AccountInfo < ImmutableRecord
    attribute :email, default: nil
    attribute :organization, default: nil
    attribute :subscription_type, default: nil
    attribute :token_source, default: nil
    attribute :api_key_source, default: nil
  end

  # Return type for supported_agents() (TypeScript SDK v0.2.63 parity)
  #
  # @example
  #   agent = AgentInfo.new(name: "Explore", description: "Search agent", model: "haiku")
  #   agent.name         # => "Explore"
  #   agent.description  # => "Search agent"
  #
  class AgentInfo < ImmutableRecord
    attribute :name
    attribute :description, default: nil
    attribute :model, default: nil
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
  class AgentDefinition < ImmutableRecord
    attribute :description
    attribute :prompt
    attribute :tools, default: nil
    attribute :disallowed_tools, default: nil
    attribute :model, default: nil
    attribute :mcp_servers, default: nil
    attribute :critical_system_reminder, default: nil
    attribute :skills, default: nil
    attribute :max_turns, default: nil

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
  class InitializationResult < ImmutableRecord
    attribute :commands, default: []
    attribute :output_style, default: nil
    attribute :available_output_styles, default: []
    attribute :models, default: []
    attribute :account, default: nil
    attribute :agents, default: []
    attribute :fast_mode_state, default: nil
  end
end
