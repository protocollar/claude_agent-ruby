# frozen_string_literal: true

module ClaudeAgent
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
  class HookProgressMessage < ImmutableRecord
    include Message

    attribute :uuid
    attribute :session_id
    attribute :hook_id
    attribute :hook_name
    attribute :hook_event
    attribute :stdout, default: ""
    attribute :stderr, default: ""
    attribute :output, default: ""

    def type
      :hook_progress
    end
  end
end
