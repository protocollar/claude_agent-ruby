# frozen_string_literal: true

module ClaudeAgent
  # API retry message (TypeScript SDK v0.2.77 parity)
  #
  # Emitted when an API request fails with a retryable error and will be
  # retried after a delay. Exposes attempt count, max retries, delay, and
  # error status for observability.
  #
  # @example
  #   msg = APIRetryMessage.new(
  #     uuid: "msg-123",
  #     session_id: "session-abc",
  #     attempt: 1,
  #     max_retries: 3,
  #     retry_delay_ms: 5000,
  #     error_status: 529,
  #     error: "rate_limit"
  #   )
  #
  class APIRetryMessage < ImmutableRecord
    include Message

    attribute :uuid, default: ""
    attribute :session_id, default: ""
    attribute :attempt, default: 0
    attribute :max_retries, default: 0
    attribute :retry_delay_ms, default: 0
    attribute :error_status, default: nil
    attribute :error, default: nil

    def type
      :api_retry
    end
  end
end
