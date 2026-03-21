# frozen_string_literal: true

module ClaudeAgent
  # System message (internal events)
  #
  # @example
  #   msg = SystemMessage.new(subtype: "init", data: {version: "2.0.0"})
  #
  class SystemMessage < ImmutableRecord
    attribute :subtype
    attribute :data

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
  class CompactBoundaryMessage < ImmutableRecord
    attribute :uuid
    attribute :session_id
    attribute :compact_metadata

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
  class APIRetryMessage < ImmutableRecord
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

  class StatusMessage < ImmutableRecord
    attribute :uuid
    attribute :session_id
    attribute :status
    attribute :permission_mode, default: nil

    def type
      :status
    end
  end
end
