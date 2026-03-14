# frozen_string_literal: true

module ClaudeAgent
  # Tool result block
  #
  # @example
  #   block = ToolResultBlock.new(tool_use_id: "tool_123", content: "file contents", is_error: false)
  #
  ToolResultBlock = Data.define(:tool_use_id, :content, :is_error) do
    def initialize(tool_use_id:, content: nil, is_error: nil)
      super
    end

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
