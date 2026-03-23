# frozen_string_literal: true

module ClaudeAgent
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
    include Message

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
