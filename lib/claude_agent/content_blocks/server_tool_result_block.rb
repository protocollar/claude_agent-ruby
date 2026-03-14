# frozen_string_literal: true

module ClaudeAgent
  # Server tool result block
  #
  ServerToolResultBlock = Data.define(:tool_use_id, :content, :is_error, :server_name) do
    def initialize(tool_use_id:, server_name:, content: nil, is_error: nil)
      super
    end

    def type
      :server_tool_result
    end

    def to_h
      h = { type: "server_tool_result", tool_use_id: tool_use_id, server_name: server_name }
      h[:content] = content unless content.nil?
      h[:is_error] = is_error unless is_error.nil?
      h
    end
  end
end
