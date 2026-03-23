# frozen_string_literal: true

module ClaudeAgent
  # User message replay (TypeScript SDK parity)
  #
  # Sent when resuming a session with existing conversation history.
  # These messages represent replayed user messages from a previous session.
  #
  # @example
  #   msg = UserMessageReplay.new(
  #     content: "Hello!",
  #     uuid: "abc-123",
  #     session_id: "session-abc",
  #     is_replay: true
  #   )
  #   msg.replay?  # => true
  #
  class UserMessageReplay < ImmutableRecord
    include Message

    attribute :content
    attribute :uuid, default: nil
    attribute :session_id, default: nil
    attribute :parent_tool_use_id, default: nil
    attribute :is_replay, default: true
    attribute :is_synthetic, default: nil
    attribute :tool_use_result, default: nil

    def type
      :user
    end

    # Get text content if content is a string
    # @return [String, nil]
    def text
      content.is_a?(String) ? content : nil
    end

    # Check if this is a replayed message
    # @return [Boolean]
    def replay?
      is_replay == true
    end

    # Check if this is a synthetic message (system-generated)
    # @return [Boolean]
    def synthetic?
      is_synthetic == true
    end
  end
end
