# frozen_string_literal: true

module ClaudeAgent
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
end
