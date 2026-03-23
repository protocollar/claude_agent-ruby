# frozen_string_literal: true

module ClaudeAgent
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
    include Message

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
end
