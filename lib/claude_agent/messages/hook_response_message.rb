# frozen_string_literal: true

module ClaudeAgent
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
  class HookResponseMessage < ImmutableRecord
    include Message

    attribute :uuid
    attribute :session_id
    attribute :hook_name
    attribute :hook_event
    attribute :hook_id, default: nil
    attribute :stdout, default: ""
    attribute :stderr, default: ""
    attribute :output, default: ""
    attribute :exit_code, default: nil
    attribute :outcome, default: nil

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
