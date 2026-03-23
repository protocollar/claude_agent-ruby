# frozen_string_literal: true

module ClaudeAgent
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
