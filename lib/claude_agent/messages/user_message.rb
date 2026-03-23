# frozen_string_literal: true

module ClaudeAgent
  # User message sent to Claude
  #
  # @example
  #   msg = UserMessage.new(content: "Hello!", uuid: "abc-123", session_id: "session-abc")
  #
  class UserMessage < ImmutableRecord
    include Message

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
end
