# frozen_string_literal: true

module ClaudeAgent
  # Task notification message (TypeScript SDK parity)
  #
  # Sent when a background task completes, fails, or is stopped.
  # Used for tracking async task execution status.
  #
  # @example
  #   msg = TaskNotificationMessage.new(
  #     uuid: "msg-123",
  #     session_id: "session-abc",
  #     task_id: "task-456",
  #     status: "completed",
  #     output_file: "/path/to/output.txt",
  #     summary: "Task completed successfully"
  #   )
  #   msg.completed?  # => true
  #   msg.failed?     # => false
  #
  # Status values:
  # - "completed" - Task finished successfully
  # - "failed" - Task encountered an error
  # - "stopped" - Task was manually stopped
  #
  class TaskNotificationMessage < ImmutableRecord
    include Message

    attribute :uuid
    attribute :session_id
    attribute :task_id
    attribute :status
    attribute :output_file
    attribute :summary
    attribute :tool_use_id, default: nil
    attribute :usage, default: nil

    def type
      :task_notification
    end

    # Check if task completed successfully
    # @return [Boolean]
    def completed?
      status == "completed"
    end

    # Check if task failed
    # @return [Boolean]
    def failed?
      status == "failed"
    end

    # Check if task was stopped
    # @return [Boolean]
    def stopped?
      status == "stopped"
    end
  end
end
