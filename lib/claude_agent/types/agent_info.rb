# frozen_string_literal: true

module ClaudeAgent
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
end
