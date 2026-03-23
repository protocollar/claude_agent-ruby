# frozen_string_literal: true

module ClaudeAgent
  # Local command output message (TypeScript SDK v0.2.63 parity)
  #
  # Contains output from a local command execution.
  #
  # @example
  #   msg = LocalCommandOutputMessage.new(
  #     uuid: "msg-123",
  #     session_id: "session-abc",
  #     content: "command output here"
  #   )
  #
  class LocalCommandOutputMessage < ImmutableRecord
    include Message

    attribute :uuid, default: ""
    attribute :session_id, default: ""
    attribute :content, default: ""

    def type
      :local_command_output
    end
  end
end
