# frozen_string_literal: true

module ClaudeAgent
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
  class StatusMessage < ImmutableRecord
    include Message

    attribute :uuid
    attribute :session_id
    attribute :status
    attribute :permission_mode, default: nil

    def type
      :status
    end
  end
end
