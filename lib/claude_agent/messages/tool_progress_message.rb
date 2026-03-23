# frozen_string_literal: true

module ClaudeAgent
  # Tool progress message (TypeScript SDK parity)
  #
  # Reports progress during long-running tool executions.
  #
  # @example
  #   msg = ToolProgressMessage.new(
  #     uuid: "msg-123",
  #     session_id: "session-abc",
  #     tool_use_id: "tool-456",
  #     tool_name: "Bash",
  #     elapsed_time_seconds: 5.2
  #   )
  #
  class ToolProgressMessage < ImmutableRecord
    include Message

    attribute :uuid
    attribute :session_id
    attribute :tool_use_id
    attribute :tool_name
    attribute :elapsed_time_seconds
    attribute :parent_tool_use_id, default: nil
    attribute :task_id, default: nil

    def type
      :tool_progress
    end
  end
end
