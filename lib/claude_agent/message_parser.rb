# frozen_string_literal: true

module ClaudeAgent
  # Parses raw JSON messages from the CLI into typed message objects
  #
  # @example
  #   parser = MessageParser.new
  #   message = parser.parse({"type" => "assistant", "message" => {...}})
  #
  class MessageParser
    # @param logger [Logger, nil] Optional logger instance
    def initialize(logger: nil)
      @logger = logger
    end

    # Parse a raw message hash into a typed message object
    #
    # @param raw [Hash] Raw message from CLI (string or symbol keys, camelCase or snake_case)
    # @return [UserMessage, UserMessageReplay, AssistantMessage, SystemMessage, ResultMessage, StreamEvent, CompactBoundaryMessage, StatusMessage, ToolProgressMessage, HookResponseMessage, AuthStatusMessage, TaskNotificationMessage, HookStartedMessage, HookProgressMessage, ToolUseSummaryMessage, FilesPersistedEvent, TaskStartedMessage, RateLimitEvent, PromptSuggestionMessage]
    # @raise [MessageParseError] If message cannot be parsed
    def parse(raw)
      raw = raw.deep_transform_keys { |key| key.to_s.underscore.to_sym }
      type = raw[:type]
      logger.debug("parser") { "Parsing message: #{type}" }

      case type
      when "user"
        parse_user_message(raw)
      when "assistant"
        parse_assistant_message(raw)
      when "system"
        # Check for special system subtypes
        case raw[:subtype]
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
        when "files_persisted"
          parse_files_persisted_event(raw)
        when "task_started"
          parse_task_started_message(raw)
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
      when "rate_limit_event"
        parse_rate_limit_event(raw)
      when "prompt_suggestion"
        parse_prompt_suggestion_message(raw)
      else
        logger.error("parser") { "Unknown message type: #{type}" }
        raise MessageParseError.new("Unknown message type: #{type}", raw_message: raw)
      end
    end

    private

    def logger
      @logger || ClaudeAgent.logger
    end

    def parse_user_message(raw)
      message = raw[:message] || {}
      content = parse_user_content(message[:content])

      is_replay = raw[:is_replay]
      is_synthetic = raw[:is_synthetic]
      tool_use_result = raw[:tool_use_result]

      if is_replay
        UserMessageReplay.new(
          content: content,
          uuid: raw[:uuid],
          session_id: raw[:session_id],
          parent_tool_use_id: raw[:parent_tool_use_id],
          is_replay: true,
          is_synthetic: is_synthetic,
          tool_use_result: tool_use_result
        )
      else
        UserMessage.new(
          content: content,
          uuid: raw[:uuid],
          session_id: raw[:session_id],
          parent_tool_use_id: raw[:parent_tool_use_id]
        )
      end
    end

    def parse_assistant_message(raw)
      message = raw[:message] || {}
      content_raw = message[:content] || []
      content = content_raw.map { |block| parse_content_block(block) }

      AssistantMessage.new(
        content: content,
        model: message[:model] || raw[:model] || "unknown",
        uuid: raw[:uuid],
        session_id: raw[:session_id],
        error: message[:error] || raw[:error],
        parent_tool_use_id: raw[:parent_tool_use_id]
      )
    end

    def parse_system_message(raw)
      SystemMessage.new(
        subtype: raw[:subtype] || "unknown",
        data: raw[:data] || raw
      )
    end

    def parse_compact_boundary_message(raw)
      CompactBoundaryMessage.new(
        uuid: raw[:uuid] || "",
        session_id: raw[:session_id] || "",
        compact_metadata: raw[:compact_metadata] || {}
      )
    end

    def parse_result_message(raw)
      permission_denials = parse_permission_denials(raw[:permission_denials])

      ResultMessage.new(
        subtype: raw[:subtype] || "unknown",
        duration_ms: raw[:duration_ms] || 0,
        duration_api_ms: raw[:duration_api_ms] || 0,
        is_error: raw[:is_error] || false,
        num_turns: raw[:num_turns] || 0,
        session_id: raw[:session_id] || "",
        total_cost_usd: raw[:total_cost_usd],
        usage: raw[:usage],
        result: raw[:result],
        structured_output: raw[:structured_output],
        errors: raw[:errors],
        permission_denials: permission_denials,
        model_usage: raw[:model_usage],
        stop_reason: raw[:stop_reason]
      )
    end

    def parse_permission_denials(denials)
      return nil unless denials.is_a?(Array)

      denials.map do |denial|
        SDKPermissionDenial.new(
          tool_name: denial[:tool_name],
          tool_use_id: denial[:tool_use_id],
          tool_input: denial[:tool_input]
        )
      end
    end

    def parse_stream_event(raw)
      StreamEvent.new(
        uuid: raw[:uuid] || "",
        session_id: raw[:session_id] || "",
        event: raw[:event] || {},
        parent_tool_use_id: raw[:parent_tool_use_id]
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

      type = block[:type]

      case type
      when "text"
        TextBlock.new(text: block[:text] || "")
      when "thinking"
        ThinkingBlock.new(
          thinking: block[:thinking] || "",
          signature: block[:signature] || ""
        )
      when "tool_use"
        ToolUseBlock.new(
          id: block[:id] || "",
          name: block[:name] || "",
          input: block[:input] || {}
        )
      when "tool_result"
        ToolResultBlock.new(
          tool_use_id: block[:tool_use_id] || "",
          content: block[:content],
          is_error: block[:is_error]
        )
      when "server_tool_use"
        ServerToolUseBlock.new(
          id: block[:id] || "",
          name: block[:name] || "",
          input: block[:input] || {},
          server_name: block[:server_name] || ""
        )
      when "server_tool_result"
        ServerToolResultBlock.new(
          tool_use_id: block[:tool_use_id] || "",
          content: block[:content],
          is_error: block[:is_error],
          server_name: block[:server_name] || ""
        )
      when "image"
        ImageContentBlock.new(
          source: block[:source] || {}
        )
      else
        # Return raw hash for unknown block types
        block
      end
    end

    def parse_status_message(raw)
      StatusMessage.new(
        uuid: raw[:uuid] || "",
        session_id: raw[:session_id] || "",
        status: raw[:status]
      )
    end

    def parse_tool_progress_message(raw)
      ToolProgressMessage.new(
        uuid: raw[:uuid] || "",
        session_id: raw[:session_id] || "",
        tool_use_id: raw[:tool_use_id] || "",
        tool_name: raw[:tool_name] || "",
        parent_tool_use_id: raw[:parent_tool_use_id],
        elapsed_time_seconds: raw[:elapsed_time_seconds] || 0
      )
    end

    def parse_hook_response_message(raw)
      HookResponseMessage.new(
        uuid: raw[:uuid] || "",
        session_id: raw[:session_id] || "",
        hook_id: raw[:hook_id],
        hook_name: raw[:hook_name] || "",
        hook_event: raw[:hook_event] || "",
        stdout: raw[:stdout] || "",
        stderr: raw[:stderr] || "",
        output: raw[:output] || "",
        exit_code: raw[:exit_code],
        outcome: raw[:outcome]
      )
    end

    def parse_auth_status_message(raw)
      AuthStatusMessage.new(
        uuid: raw[:uuid] || "",
        session_id: raw[:session_id] || "",
        is_authenticating: raw[:is_authenticating] || false,
        output: raw[:output] || [],
        error: raw[:error]
      )
    end

    def parse_task_notification_message(raw)
      TaskNotificationMessage.new(
        uuid: raw[:uuid] || "",
        session_id: raw[:session_id] || "",
        task_id: raw[:task_id] || "",
        status: raw[:status] || "unknown",
        output_file: raw[:output_file] || "",
        summary: raw[:summary] || ""
      )
    end

    def parse_hook_started_message(raw)
      HookStartedMessage.new(
        uuid: raw[:uuid] || "",
        session_id: raw[:session_id] || "",
        hook_id: raw[:hook_id] || "",
        hook_name: raw[:hook_name] || "",
        hook_event: raw[:hook_event] || ""
      )
    end

    def parse_hook_progress_message(raw)
      HookProgressMessage.new(
        uuid: raw[:uuid] || "",
        session_id: raw[:session_id] || "",
        hook_id: raw[:hook_id] || "",
        hook_name: raw[:hook_name] || "",
        hook_event: raw[:hook_event] || "",
        stdout: raw[:stdout] || "",
        stderr: raw[:stderr] || "",
        output: raw[:output] || ""
      )
    end

    def parse_tool_use_summary_message(raw)
      ToolUseSummaryMessage.new(
        uuid: raw[:uuid] || "",
        session_id: raw[:session_id] || "",
        summary: raw[:summary] || "",
        preceding_tool_use_ids: raw[:preceding_tool_use_ids] || []
      )
    end

    def parse_files_persisted_event(raw)
      FilesPersistedEvent.new(
        uuid: raw[:uuid] || "",
        session_id: raw[:session_id] || "",
        files: raw[:files] || [],
        failed: raw[:failed] || [],
        processed_at: raw[:processed_at]
      )
    end

    def parse_task_started_message(raw)
      TaskStartedMessage.new(
        uuid: raw[:uuid] || "",
        session_id: raw[:session_id] || "",
        task_id: raw[:task_id] || "",
        tool_use_id: raw[:tool_use_id],
        description: raw[:description],
        task_type: raw[:task_type]
      )
    end

    def parse_rate_limit_event(raw)
      RateLimitEvent.new(
        rate_limit_info: raw[:rate_limit_info] || {},
        uuid: raw[:uuid] || "",
        session_id: raw[:session_id] || ""
      )
    end

    def parse_prompt_suggestion_message(raw)
      PromptSuggestionMessage.new(
        uuid: raw[:uuid] || "",
        session_id: raw[:session_id] || "",
        suggestion: raw[:suggestion] || ""
      )
    end
  end
end
