# frozen_string_literal: true

module ClaudeAgent
  # Elicitation complete message (TypeScript SDK v0.2.63 parity)
  #
  # Sent when an MCP server elicitation request completes.
  #
  # @example
  #   msg = ElicitationCompleteMessage.new(
  #     uuid: "msg-123",
  #     session_id: "session-abc",
  #     mcp_server_name: "my-server",
  #     elicitation_id: "elic-456"
  #   )
  #
  class ElicitationCompleteMessage < ImmutableRecord
    include Message

    attribute :uuid, default: ""
    attribute :session_id, default: ""
    attribute :mcp_server_name, default: ""
    attribute :elicitation_id, default: ""

    def type
      :elicitation_complete
    end
  end
end
