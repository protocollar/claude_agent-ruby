# frozen_string_literal: true

module ClaudeAgent
  # User message sent to Claude
  #
  # @example
  #   msg = UserMessage.new(content: "Hello!", uuid: "abc-123", session_id: "session-abc")
  #
  UserMessage = Data.define(:content, :uuid, :session_id, :parent_tool_use_id) do
    def initialize(content:, uuid: nil, session_id: nil, parent_tool_use_id: nil)
      super
    end

    def type
      :user
    end

    # Get text content if content is a string
    # @return [String, nil]
    def text
      content.is_a?(String) ? content : nil
    end

    # Check if this is a replayed message
    # @return [Boolean]
    def replay?
      false
    end
  end

  # User message replay (TypeScript SDK parity)
  #
  # Sent when resuming a session with existing conversation history.
  # These messages represent replayed user messages from a previous session.
  #
  # @example
  #   msg = UserMessageReplay.new(
  #     content: "Hello!",
  #     uuid: "abc-123",
  #     session_id: "session-abc",
  #     is_replay: true
  #   )
  #   msg.replay?  # => true
  #
  UserMessageReplay = Data.define(
    :content,
    :uuid,
    :session_id,
    :parent_tool_use_id,
    :is_replay,
    :is_synthetic,
    :tool_use_result
  ) do
    def initialize(
      content:,
      uuid: nil,
      session_id: nil,
      parent_tool_use_id: nil,
      is_replay: true,
      is_synthetic: nil,
      tool_use_result: nil
    )
      super
    end

    def type
      :user
    end

    # Get text content if content is a string
    # @return [String, nil]
    def text
      content.is_a?(String) ? content : nil
    end

    # Check if this is a replayed message
    # @return [Boolean]
    def replay?
      is_replay == true
    end

    # Check if this is a synthetic message (system-generated)
    # @return [Boolean]
    def synthetic?
      is_synthetic == true
    end
  end

  # Assistant message from Claude
  #
  # @example
  #   msg = AssistantMessage.new(
  #     content: [TextBlock.new(text: "Hello!")],
  #     model: "claude-sonnet-4-5-20250514",
  #     uuid: "msg-123",
  #     session_id: "session-abc"
  #   )
  #
  AssistantMessage = Data.define(:content, :model, :uuid, :session_id, :error, :parent_tool_use_id) do
    def initialize(content:, model:, uuid: nil, session_id: nil, error: nil, parent_tool_use_id: nil)
      super
    end

    def type
      :assistant
    end

    # Get all text content concatenated
    # @return [String]
    def text
      content
        .select { |block| block.is_a?(TextBlock) }
        .map(&:text)
        .join
    end

    # Get all thinking content concatenated
    # @return [String]
    def thinking
      content
        .select { |block| block.is_a?(ThinkingBlock) }
        .map(&:thinking)
        .join
    end

    # Get all tool use blocks
    # @return [Array<ToolUseBlock>]
    def tool_uses
      content.select { |block| block.is_a?(ToolUseBlock) }
    end

    # Check if assistant wants to use a tool
    # @return [Boolean]
    def has_tool_use?
      content.any? { |block| block.is_a?(ToolUseBlock) }
    end
  end

  # System message (internal events)
  #
  # @example
  #   msg = SystemMessage.new(subtype: "init", data: {version: "2.0.0"})
  #
  SystemMessage = Data.define(:subtype, :data) do
    def type
      :system
    end
  end

  # Result message (final message with usage/cost info) - TypeScript SDK parity
  #
  # @example Success result
  #   msg = ResultMessage.new(
  #     subtype: "success",
  #     duration_ms: 1500,
  #     duration_api_ms: 1200,
  #     is_error: false,
  #     num_turns: 3,
  #     session_id: "session-abc",
  #     total_cost_usd: 0.05,
  #     usage: {input_tokens: 100, output_tokens: 50}
  #   )
  #
  # @example Error result
  #   msg = ResultMessage.new(
  #     subtype: "error_max_turns",
  #     errors: ["Maximum turns exceeded"],
  #     ...
  #   )
  #
  ResultMessage = Data.define(
    :subtype,
    :duration_ms,
    :duration_api_ms,
    :is_error,
    :num_turns,
    :session_id,
    :total_cost_usd,
    :usage,
    :result,
    :structured_output,
    :errors,             # Array<String> for error subtypes
    :permission_denials, # Array<SDKPermissionDenial>
    :model_usage         # Hash with per-model usage breakdown
  ) do
    def initialize(
      subtype:,
      duration_ms:,
      duration_api_ms:,
      is_error:,
      num_turns:,
      session_id:,
      total_cost_usd: nil,
      usage: nil,
      result: nil,
      structured_output: nil,
      errors: nil,
      permission_denials: nil,
      model_usage: nil
    )
      super
    end

    def type
      :result
    end

    # Check if this was an error result
    # @return [Boolean]
    def error?
      is_error
    end

    # Check if this was a successful result
    # @return [Boolean]
    def success?
      !is_error
    end
  end

  # Stream event (partial message during streaming)
  #
  # @example
  #   event = StreamEvent.new(
  #     uuid: "evt-123",
  #     session_id: "session-abc",
  #     event: {type: "content_block_delta", delta: {type: "text_delta", text: "Hello"}}
  #   )
  #
  StreamEvent = Data.define(:uuid, :session_id, :event, :parent_tool_use_id) do
    def initialize(uuid:, session_id:, event:, parent_tool_use_id: nil)
      super
    end

    def type
      :stream_event
    end

    # Get the event type from the raw event
    # @return [String, nil]
    def event_type
      event["type"]
    end
  end

  # Compact boundary message (conversation compaction marker) - TypeScript SDK parity
  #
  # Sent when the conversation is compacted to reduce context size.
  # Contains metadata about the compaction operation.
  #
  # @example
  #   msg = CompactBoundaryMessage.new(
  #     uuid: "msg-123",
  #     session_id: "session-abc",
  #     compact_metadata: { trigger: "auto", pre_tokens: 50000 }
  #   )
  #   msg.trigger     # => "auto"
  #   msg.pre_tokens  # => 50000
  #
  CompactBoundaryMessage = Data.define(:uuid, :session_id, :compact_metadata) do
    def type
      :compact_boundary
    end

    # Get the compaction trigger type
    # @return [String] "manual" or "auto"
    def trigger
      compact_metadata[:trigger] || compact_metadata["trigger"]
    end

    # Get the token count before compaction
    # @return [Integer, nil]
    def pre_tokens
      compact_metadata[:pre_tokens] || compact_metadata["pre_tokens"]
    end
  end

  # Status message (TypeScript SDK parity)
  #
  # Reports session status like 'compacting' during operations.
  #
  # @example
  #   msg = StatusMessage.new(
  #     uuid: "msg-123",
  #     session_id: "session-abc",
  #     status: "compacting"
  #   )
  #
  StatusMessage = Data.define(:uuid, :session_id, :status) do
    def type
      :status
    end
  end

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
    :elapsed_time_seconds
  ) do
    def initialize(
      uuid:,
      session_id:,
      tool_use_id:,
      tool_name:,
      elapsed_time_seconds:,
      parent_tool_use_id: nil
    )
      super
    end

    def type
      :tool_progress
    end
  end

  # Hook response message (TypeScript SDK parity)
  #
  # Contains output from hook executions.
  #
  # @example
  #   msg = HookResponseMessage.new(
  #     uuid: "msg-123",
  #     session_id: "session-abc",
  #     hook_name: "my-hook",
  #     hook_event: "PreToolUse",
  #     stdout: "Hook output",
  #     stderr: "",
  #     exit_code: 0
  #   )
  #
  HookResponseMessage = Data.define(
    :uuid,
    :session_id,
    :hook_name,
    :hook_event,
    :stdout,
    :stderr,
    :exit_code
  ) do
    def initialize(
      uuid:,
      session_id:,
      hook_name:,
      hook_event:,
      stdout: "",
      stderr: "",
      exit_code: nil
    )
      super
    end

    def type
      :hook_response
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
  AuthStatusMessage = Data.define(
    :uuid,
    :session_id,
    :is_authenticating,
    :output,
    :error
  ) do
    def initialize(
      uuid:,
      session_id:,
      is_authenticating:,
      output: [],
      error: nil
    )
      super
    end

    def type
      :auth_status
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
  TaskNotificationMessage = Data.define(
    :uuid,
    :session_id,
    :task_id,
    :status,
    :output_file,
    :summary
  ) do
    def initialize(
      uuid:,
      session_id:,
      task_id:,
      status:,
      output_file:,
      summary:
    )
      super
    end

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

  # All message types
  MESSAGE_TYPES = [
    UserMessage,
    UserMessageReplay,
    AssistantMessage,
    SystemMessage,
    ResultMessage,
    StreamEvent,
    CompactBoundaryMessage,
    StatusMessage,
    ToolProgressMessage,
    HookResponseMessage,
    AuthStatusMessage,
    TaskNotificationMessage
  ].freeze
end
