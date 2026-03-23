# frozen_string_literal: true

module ClaudeAgent
  # Tool result block
  #
  # @example
  #   block = ToolResultBlock.new(tool_use_id: "tool_123", content: "file contents", is_error: false)
  #
  class ToolResultBlock < ImmutableRecord
    include Message

    attribute :tool_use_id
    attribute :content, default: nil
    attribute :is_error, default: nil

    def type
      :tool_result
    end

    def to_h
      h = { type: "tool_result", tool_use_id: tool_use_id }
      h[:content] = content unless content.nil?
      h[:is_error] = is_error unless is_error.nil?
      h
    end
  end
end
