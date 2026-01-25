# frozen_string_literal: true

module ClaudeAgent
  # Parses raw JSON messages from the CLI into typed message objects
  #
  # @example
  #   parser = MessageParser.new
  #   message = parser.parse({"type" => "assistant", "message" => {...}})
  #
  class MessageParser
    # Parse a raw message hash into a typed message object
    #
    # @param raw [Hash] Raw message from CLI
    # @return [UserMessage, UserMessageReplay, AssistantMessage, SystemMessage, ResultMessage, StreamEvent, CompactBoundaryMessage, StatusMessage, ToolProgressMessage, HookResponseMessage, AuthStatusMessage, TaskNotificationMessage, HookStartedMessage, HookProgressMessage, ToolUseSummaryMessage]
    # @raise [MessageParseError] If message cannot be parsed
    def parse(raw)
      type = raw["type"]

      case type
      when "user"
        parse_user_message(raw)
      when "assistant"
        parse_assistant_message(raw)
      when "system"
        # Check for special system subtypes
        case raw["subtype"]
        when "compact_boundary"
          parse_compact_boundary_message(raw)
        when "status"
          parse_status_message(raw)
        when "hook_response"
          parse_hook_response_message(raw)
        when "task_notification"
          parse_task_notification_message(raw)
        when "hook_started"
          parse_hook_started_message(raw)
        when "hook_progress"
          parse_hook_progress_message(raw)
        else
          parse_system_message(raw)
        end
      when "result"
        parse_result_message(raw)
      when "stream_event"
        parse_stream_event(raw)
      when "tool_progress"
        parse_tool_progress_message(raw)
      when "auth_status"
        parse_auth_status_message(raw)
      when "tool_use_summary"
        parse_tool_use_summary_message(raw)
      else
        raise MessageParseError.new("Unknown message type: #{type}", raw_message: raw)
      end
    end

    private

    # Fetch a value from a hash, trying both snake_case and camelCase keys
    # @param raw [Hash] The hash to fetch from
    # @param snake_key [Symbol, String] The snake_case key to try
    # @param default [Object] Default value if neither key exists
    # @return [Object] The value or default
    def fetch_dual(raw, snake_key, default = nil)
      snake_str = snake_key.to_s
      camel_str = snake_str.camelize(:lower)
      raw[snake_str] || raw[camel_str] || default
    end

    def parse_user_message(raw)
      message = raw["message"] || {}
      content = parse_user_content(message["content"])

      is_replay = fetch_dual(raw, :is_replay)
      is_synthetic = fetch_dual(raw, :is_synthetic)
      tool_use_result = fetch_dual(raw, :tool_use_result)

      if is_replay
        UserMessageReplay.new(
          content: content,
          uuid: raw["uuid"],
          session_id: fetch_dual(raw, :session_id),
          parent_tool_use_id: raw["parent_tool_use_id"],
          is_replay: true,
          is_synthetic: is_synthetic,
          tool_use_result: tool_use_result
        )
      else
        UserMessage.new(
          content: content,
          uuid: raw["uuid"],
          session_id: fetch_dual(raw, :session_id),
          parent_tool_use_id: raw["parent_tool_use_id"]
        )
      end
    end

    def parse_assistant_message(raw)
      message = raw["message"] || {}
      content_raw = message["content"] || []
      content = content_raw.map { |block| parse_content_block(block) }

      AssistantMessage.new(
        content: content,
        model: message["model"] || raw["model"] || "unknown",
        uuid: raw["uuid"],
        session_id: fetch_dual(raw, :session_id),
        error: message["error"] || raw["error"],
        parent_tool_use_id: raw["parent_tool_use_id"]
      )
    end

    def parse_system_message(raw)
      SystemMessage.new(
        subtype: raw["subtype"] || "unknown",
        data: raw["data"] || raw
      )
    end

    def parse_compact_boundary_message(raw)
      CompactBoundaryMessage.new(
        uuid: raw["uuid"] || "",
        session_id: fetch_dual(raw, :session_id, ""),
        compact_metadata: fetch_dual(raw, :compact_metadata, {})
      )
    end

    def parse_result_message(raw)
      permission_denials = parse_permission_denials(fetch_dual(raw, :permission_denials))

      ResultMessage.new(
        subtype: raw["subtype"] || "unknown",
        duration_ms: fetch_dual(raw, :duration_ms, 0),
        duration_api_ms: fetch_dual(raw, :duration_api_ms, 0),
        is_error: fetch_dual(raw, :is_error, false),
        num_turns: fetch_dual(raw, :num_turns, 0),
        session_id: fetch_dual(raw, :session_id, ""),
        total_cost_usd: fetch_dual(raw, :total_cost_usd),
        usage: raw["usage"],
        result: raw["result"],
        structured_output: fetch_dual(raw, :structured_output),
        errors: raw["errors"],
        permission_denials: permission_denials,
        model_usage: fetch_dual(raw, :model_usage)
      )
    end

    def parse_permission_denials(denials)
      return nil unless denials.is_a?(Array)

      denials.map do |denial|
        SDKPermissionDenial.new(
          tool_name: fetch_dual(denial, :tool_name),
          tool_use_id: fetch_dual(denial, :tool_use_id),
          tool_input: fetch_dual(denial, :tool_input)
        )
      end
    end

    def parse_stream_event(raw)
      StreamEvent.new(
        uuid: raw["uuid"] || "",
        session_id: fetch_dual(raw, :session_id, ""),
        event: raw["event"] || {},
        parent_tool_use_id: raw["parent_tool_use_id"]
      )
    end

    def parse_user_content(content)
      case content
      when String
        content
      when Array
        content.map { |block| parse_content_block(block) }
      else
        content.to_s
      end
    end

    def parse_content_block(block)
      return block unless block.is_a?(Hash)

      type = block["type"]

      case type
      when "text"
        TextBlock.new(text: block["text"] || "")
      when "thinking"
        ThinkingBlock.new(
          thinking: block["thinking"] || "",
          signature: block["signature"] || ""
        )
      when "tool_use"
        ToolUseBlock.new(
          id: block["id"] || "",
          name: block["name"] || "",
          input: block["input"] || {}
        )
      when "tool_result"
        ToolResultBlock.new(
          tool_use_id: block["tool_use_id"] || "",
          content: block["content"],
          is_error: block["is_error"]
        )
      when "server_tool_use"
        ServerToolUseBlock.new(
          id: block["id"] || "",
          name: block["name"] || "",
          input: block["input"] || {},
          server_name: block["server_name"] || ""
        )
      when "server_tool_result"
        ServerToolResultBlock.new(
          tool_use_id: block["tool_use_id"] || "",
          content: block["content"],
          is_error: block["is_error"],
          server_name: block["server_name"] || ""
        )
      when "image"
        ImageContentBlock.new(
          source: block["source"] || {}
        )
      else
        # Return raw hash for unknown block types
        block
      end
    end

    def parse_status_message(raw)
      StatusMessage.new(
        uuid: raw["uuid"] || "",
        session_id: fetch_dual(raw, :session_id, ""),
        status: raw["status"]
      )
    end

    def parse_tool_progress_message(raw)
      ToolProgressMessage.new(
        uuid: raw["uuid"] || "",
        session_id: fetch_dual(raw, :session_id, ""),
        tool_use_id: fetch_dual(raw, :tool_use_id, ""),
        tool_name: fetch_dual(raw, :tool_name, ""),
        parent_tool_use_id: fetch_dual(raw, :parent_tool_use_id),
        elapsed_time_seconds: fetch_dual(raw, :elapsed_time_seconds, 0)
      )
    end

    def parse_hook_response_message(raw)
      HookResponseMessage.new(
        uuid: raw["uuid"] || "",
        session_id: fetch_dual(raw, :session_id, ""),
        hook_id: fetch_dual(raw, :hook_id),
        hook_name: fetch_dual(raw, :hook_name, ""),
        hook_event: fetch_dual(raw, :hook_event, ""),
        stdout: raw["stdout"] || "",
        stderr: raw["stderr"] || "",
        output: raw["output"] || "",
        exit_code: fetch_dual(raw, :exit_code),
        outcome: raw["outcome"]
      )
    end

    def parse_auth_status_message(raw)
      AuthStatusMessage.new(
        uuid: raw["uuid"] || "",
        session_id: fetch_dual(raw, :session_id, ""),
        is_authenticating: fetch_dual(raw, :is_authenticating, false),
        output: raw["output"] || [],
        error: raw["error"]
      )
    end

    def parse_task_notification_message(raw)
      TaskNotificationMessage.new(
        uuid: raw["uuid"] || "",
        session_id: fetch_dual(raw, :session_id, ""),
        task_id: fetch_dual(raw, :task_id, ""),
        status: raw["status"] || "unknown",
        output_file: fetch_dual(raw, :output_file, ""),
        summary: raw["summary"] || ""
      )
    end

    def parse_hook_started_message(raw)
      HookStartedMessage.new(
        uuid: raw["uuid"] || "",
        session_id: fetch_dual(raw, :session_id, ""),
        hook_id: fetch_dual(raw, :hook_id, ""),
        hook_name: fetch_dual(raw, :hook_name, ""),
        hook_event: fetch_dual(raw, :hook_event, "")
      )
    end

    def parse_hook_progress_message(raw)
      HookProgressMessage.new(
        uuid: raw["uuid"] || "",
        session_id: fetch_dual(raw, :session_id, ""),
        hook_id: fetch_dual(raw, :hook_id, ""),
        hook_name: fetch_dual(raw, :hook_name, ""),
        hook_event: fetch_dual(raw, :hook_event, ""),
        stdout: raw["stdout"] || "",
        stderr: raw["stderr"] || "",
        output: raw["output"] || ""
      )
    end

    def parse_tool_use_summary_message(raw)
      ToolUseSummaryMessage.new(
        uuid: raw["uuid"] || "",
        session_id: fetch_dual(raw, :session_id, ""),
        summary: raw["summary"] || "",
        preceding_tool_use_ids: fetch_dual(raw, :preceding_tool_use_ids, [])
      )
    end
  end
end
