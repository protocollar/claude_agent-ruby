# frozen_string_literal: true

module ClaudeAgent
  # Task started message (TypeScript SDK v0.2.45 parity)
  #
  # Sent when a new task (subagent) is started.
  #
  # @example
  #   msg = TaskStartedMessage.new(
  #     uuid: "msg-123",
  #     session_id: "session-abc",
  #     task_id: "task-456",
  #     tool_use_id: "tool-789",
  #     description: "Running tests",
  #     task_type: "bash"
  #   )
  #
  class TaskStartedMessage < ImmutableRecord
    include Message

    attribute :uuid
    attribute :session_id
    attribute :task_id
    attribute :tool_use_id, default: nil
    attribute :description, default: nil
    attribute :task_type, default: nil
    attribute :prompt, default: nil

    def type
      :task_started
    end
  end
end
