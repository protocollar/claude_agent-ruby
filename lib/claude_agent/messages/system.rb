# frozen_string_literal: true

module ClaudeAgent
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
      compact_metadata[:trigger]
    end

    # Get the token count before compaction
    # @return [Integer, nil]
    def pre_tokens
      compact_metadata[:pre_tokens]
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
  APIRetryMessage = Data.define(:uuid, :session_id, :attempt, :max_retries, :retry_delay_ms, :error_status, :error) do
    def initialize(uuid: "", session_id: "", attempt: 0, max_retries: 0, retry_delay_ms: 0, error_status: nil, error: nil)
      super
    end

    def type
      :api_retry
    end
  end

  StatusMessage = Data.define(:uuid, :session_id, :status, :permission_mode) do
    def initialize(uuid:, session_id:, status:, permission_mode: nil)
      super
    end

    def type
      :status
    end
  end
end
