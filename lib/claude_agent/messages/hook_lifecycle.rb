# frozen_string_literal: true

module ClaudeAgent
  # Hook started message (TypeScript SDK parity)
  #
  # Sent when a hook execution starts.
  #
  # @example
  #   msg = HookStartedMessage.new(
  #     uuid: "msg-123",
  #     session_id: "session-abc",
  #     hook_id: "hook-456",
  #     hook_name: "my-hook",
  #     hook_event: "PreToolUse"
  #   )
  #
  HookStartedMessage = Data.define(
    :uuid,
    :session_id,
    :hook_id,
    :hook_name,
    :hook_event
  ) do
    def initialize(
      uuid:,
      session_id:,
      hook_id:,
      hook_name:,
      hook_event:
    )
      super
    end

    def type
      :hook_started
    end
  end

  # Hook progress message (TypeScript SDK parity)
  #
  # Reports progress during hook execution.
  #
  # @example
  #   msg = HookProgressMessage.new(
  #     uuid: "msg-123",
  #     session_id: "session-abc",
  #     hook_id: "hook-456",
  #     hook_name: "my-hook",
  #     hook_event: "PreToolUse",
  #     stdout: "Hook output so far...",
  #     stderr: "",
  #     output: "Combined output"
  #   )
  #
  HookProgressMessage = Data.define(
    :uuid,
    :session_id,
    :hook_id,
    :hook_name,
    :hook_event,
    :stdout,
    :stderr,
    :output
  ) do
    def initialize(
      uuid:,
      session_id:,
      hook_id:,
      hook_name:,
      hook_event:,
      stdout: "",
      stderr: "",
      output: ""
    )
      super
    end

    def type
      :hook_progress
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
  #     hook_id: "hook-456",
  #     hook_name: "my-hook",
  #     hook_event: "PreToolUse",
  #     stdout: "Hook output",
  #     stderr: "",
  #     output: "Combined output",
  #     exit_code: 0,
  #     outcome: "success"
  #   )
  #   msg.success?    # => true
  #   msg.error?      # => false
  #   msg.cancelled?  # => false
  #
  # Outcome values:
  # - "success" - Hook completed successfully
  # - "error" - Hook encountered an error
  # - "cancelled" - Hook was cancelled
  #
  HookResponseMessage = Data.define(
    :uuid,
    :session_id,
    :hook_id,
    :hook_name,
    :hook_event,
    :stdout,
    :stderr,
    :output,
    :exit_code,
    :outcome
  ) do
    def initialize(
      uuid:,
      session_id:,
      hook_id: nil,
      hook_name:,
      hook_event:,
      stdout: "",
      stderr: "",
      output: "",
      exit_code: nil,
      outcome: nil
    )
      super
    end

    def type
      :hook_response
    end

    # Check if hook completed successfully
    # @return [Boolean]
    def success?
      outcome == "success"
    end

    # Check if hook encountered an error
    # @return [Boolean]
    def error?
      outcome == "error"
    end

    # Check if hook was cancelled
    # @return [Boolean]
    def cancelled?
      outcome == "cancelled"
    end
  end
end
