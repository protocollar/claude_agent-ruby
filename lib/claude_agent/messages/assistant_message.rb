# frozen_string_literal: true

module ClaudeAgent
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
    include Message

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
