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
  ToolProgressMessage = Data.define(
    :uuid,
    :session_id,
    :tool_use_id,
    :tool_name,
    :parent_tool_use_id,
    :elapsed_time_seconds,
    :task_id
  ) do
    def initialize(
      uuid:,
      session_id:,
      tool_use_id:,
      tool_name:,
      elapsed_time_seconds:,
      parent_tool_use_id: nil,
      task_id: nil
    )
      super
    end

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
  ToolUseSummaryMessage = Data.define(
    :uuid,
    :session_id,
    :summary,
    :preceding_tool_use_ids
  ) do
    def initialize(
      uuid:,
      session_id:,
      summary:,
      preceding_tool_use_ids: []
    )
      super
    end

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
  LocalCommandOutputMessage = Data.define(:uuid, :session_id, :content) do
    def initialize(uuid: "", session_id: "", content: "")
      super
    end

    def type
      :local_command_output
    end
  end
end
