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
  class HookStartedMessage < ImmutableRecord
    include Message

    attribute :uuid
    attribute :session_id
    attribute :hook_id
    attribute :hook_name
    attribute :hook_event

    def type
      :hook_started
    end
  end
end
