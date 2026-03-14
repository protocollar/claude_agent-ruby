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
  StatusMessage = Data.define(:uuid, :session_id, :status, :permission_mode) do
    def initialize(uuid:, session_id:, status:, permission_mode: nil)
      super
    end

    def type
      :status
    end
  end
end
