# frozen_string_literal: true

module ClaudeAgent
  # Server tool result block
  #
  class ServerToolResultBlock < ImmutableRecord
    attribute :tool_use_id
    attribute :server_name
    attribute :content, default: nil
    attribute :is_error, default: nil

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
