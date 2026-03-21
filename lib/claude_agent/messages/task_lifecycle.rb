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

  # Files persisted event (TypeScript SDK v0.2.25 parity)
  #
  # Sent when files are persisted to storage during a session.
  # Contains lists of successfully persisted files and any failures.
  #
  # @example
  #   msg = FilesPersistedEvent.new(
  #     uuid: "msg-123",
  #     session_id: "session-abc",
  #     files: [{ filename: "test.rb", file_id: "file-456" }],
  #     failed: [],
  #     processed_at: "2026-01-30T12:00:00Z"
  #   )
  #   msg.files.first[:filename]  # => "test.rb"
  #
  class FilesPersistedEvent < ImmutableRecord
    attribute :uuid
    attribute :session_id
    attribute :files, default: []
    attribute :failed, default: []
    attribute :processed_at, default: nil

    def type
      :files_persisted
    end
  end

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
    attribute :uuid, default: ""
    attribute :session_id, default: ""
    attribute :mcp_server_name, default: ""
    attribute :elicitation_id, default: ""

    def type
      :elicitation_complete
    end
  end

  # Auth status message (TypeScript SDK parity)
  #
  # Reports authentication status during login flows.
  #
  # @example
  #   msg = AuthStatusMessage.new(
  #     uuid: "msg-123",
  #     session_id: "session-abc",
  #     is_authenticating: true,
  #     output: ["Waiting for browser..."]
  #   )
  #
  class AuthStatusMessage < ImmutableRecord
    attribute :uuid
    attribute :session_id
    attribute :is_authenticating
    attribute :output, default: []
    attribute :error, default: nil

    def type
      :auth_status
    end
  end
end
