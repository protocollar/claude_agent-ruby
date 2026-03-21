# frozen_string_literal: true

module ClaudeAgent
  # User message sent to Claude
  #
  # @example
  #   msg = UserMessage.new(content: "Hello!", uuid: "abc-123", session_id: "session-abc")
  #
  class UserMessage < ImmutableRecord
    attribute :content
    attribute :uuid, default: nil
    attribute :session_id, default: nil
    attribute :parent_tool_use_id, default: nil

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
      false
    end
  end

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

  # Assistant message from Claude
  #
  # @example
  #   msg = AssistantMessage.new(
  #     content: [TextBlock.new(text: "Hello!")],
  #     model: "claude-sonnet-4-5-20250514",
  #     uuid: "msg-123",
  #     session_id: "session-abc"
  #   )
  #
  class AssistantMessage < ImmutableRecord
    attribute :content
    attribute :model
    attribute :uuid, default: nil
    attribute :session_id, default: nil
    attribute :error, default: nil
    attribute :parent_tool_use_id, default: nil

    def type
      :assistant
    end

    # Get all text content concatenated
    # @return [String]
    def text
      content
        .select { |block| block.is_a?(TextBlock) }
        .map(&:text)
        .join
    end

    # Get all thinking content concatenated
    # @return [String]
    def thinking
      content
        .select { |block| block.is_a?(ThinkingBlock) }
        .map(&:thinking)
        .join
    end

    # Get all tool use blocks
    # @return [Array<ToolUseBlock>]
    def tool_uses
      content.select { |block| block.is_a?(ToolUseBlock) }
    end

    # Check if assistant wants to use a tool
    # @return [Boolean]
    def has_tool_use?
      content.any? { |block| block.is_a?(ToolUseBlock) }
    end
  end
end
