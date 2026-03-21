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

  # Tool use summary message (TypeScript SDK parity)
  #
  # Contains a summary of tool use for collapsed display.
  #
  # @example
  #   msg = ToolUseSummaryMessage.new(
  #     uuid: "msg-123",
  #     session_id: "session-abc",
  #     summary: "Read 3 files",
  #     preceding_tool_use_ids: ["tool-1", "tool-2", "tool-3"]
  #   )
  #
  class ToolUseSummaryMessage < ImmutableRecord
    attribute :uuid
    attribute :session_id
    attribute :summary
    attribute :preceding_tool_use_ids, default: []

    def type
      :tool_use_summary
    end
  end

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
    attribute :uuid, default: ""
    attribute :session_id, default: ""
    attribute :content, default: ""

    def type
      :local_command_output
    end
  end
end
