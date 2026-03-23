# frozen_string_literal: true

module ClaudeAgent
  # Task progress message (TypeScript SDK v0.2.51 parity)
  #
  # Reports progress during background task (subagent) execution.
  # Contains usage information and description of what the task is doing.
  #
  # @example
  #   msg = TaskProgressMessage.new(
  #     uuid: "msg-123",
  #     session_id: "session-abc",
  #     task_id: "task-456",
  #     description: "Searching codebase for patterns",
  #     usage: { total_tokens: 5000, tool_uses: 3, duration_ms: 2500 }
  #   )
  #
  class TaskProgressMessage < ImmutableRecord
    include Message

    attribute :uuid
    attribute :session_id
    attribute :task_id
    attribute :description
    attribute :tool_use_id, default: nil
    attribute :usage, default: nil
    attribute :last_tool_name, default: nil
    attribute :summary, default: nil

    def type
      :task_progress
    end
  end
end
