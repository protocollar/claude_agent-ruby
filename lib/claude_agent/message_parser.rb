# frozen_string_literal: true

module ClaudeAgent
  # Parses raw JSON messages from the CLI into typed message objects
  #
  # Uses a registry to route messages by type (and subtype for system messages)
  # to named parse methods. New message types can be added with a single
  # {.register} call instead of modifying case statements.
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

    # Registry of parser methods keyed by routing string.
    # Keys are "type" for top-level types, "type:subtype" for system subtypes.
    @registry = {}

    class << self
      attr_reader :registry

      # Register a parse method for a message type
      #
      # @param key [String] Routing key ("type" or "type:subtype")
      # @param method_name [Symbol] Name of the private parse method
      def register(key, method_name)
        @registry[key] = method_name
      end
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

      # Look up parser: try specific system subtype first, then top-level type
      method_name = if type == "system" && raw[:subtype]
        self.class.registry["system:#{raw[:subtype]}"] || self.class.registry["system"]
      else
        self.class.registry[type]
      end

      if method_name
        send(method_name, raw)
      else
        logger.warn("parser") { "Unknown message type: #{type}, wrapping in GenericMessage" }
        GenericMessage.new(message_type: type.to_s, raw: raw)
      end
    end

    # --- Parser Registration ---
    #
    # Top-level message types

    register "user",              :parse_user_message
    register "assistant",         :parse_assistant_message
    register "result",            :parse_result_message
    register "stream_event",      :parse_stream_event
    register "tool_progress",     :parse_tool_progress_message
    register "auth_status",       :parse_auth_status_message
    register "tool_use_summary",  :parse_tool_use_summary_message
    register "rate_limit_event",  :parse_rate_limit_event
    register "prompt_suggestion", :parse_prompt_suggestion_message

    # System message subtypes

    register "system",                   :parse_system_message             # fallback for unknown subtypes
    register "system:compact_boundary",  :parse_compact_boundary_message
    register "system:status",            :parse_status_message
    register "system:hook_response",     :parse_hook_response_message
    register "system:task_notification", :parse_task_notification_message
    register "system:hook_started",      :parse_hook_started_message
    register "system:hook_progress",     :parse_hook_progress_message
    register "system:files_persisted",   :parse_files_persisted_event
    register "system:task_started",      :parse_task_started_message
    register "system:task_progress",            :parse_task_progress_message
    register "system:elicitation_complete",    :parse_elicitation_complete_message
    register "system:local_command_output",    :parse_local_command_output_message

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
        uuid: raw[:uuid],
        total_cost_usd: raw[:total_cost_usd],
        usage: raw[:usage],
        result: raw[:result],
        structured_output: raw[:structured_output],
        errors: raw[:errors],
        permission_denials: permission_denials,
        model_usage: raw[:model_usage],
        stop_reason: raw[:stop_reason],
        fast_mode_state: raw[:fast_mode_state]
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
        GenericBlock.new(block_type: type.to_s, raw: block)
      end
    end

    def parse_status_message(raw)
      StatusMessage.new(
        uuid: raw[:uuid] || "",
        session_id: raw[:session_id] || "",
        status: raw[:status],
        permission_mode: raw[:permission_mode]
      )
    end

    def parse_tool_progress_message(raw)
      ToolProgressMessage.new(
        uuid: raw[:uuid] || "",
        session_id: raw[:session_id] || "",
        tool_use_id: raw[:tool_use_id] || "",
        tool_name: raw[:tool_name] || "",
        parent_tool_use_id: raw[:parent_tool_use_id],
        elapsed_time_seconds: raw[:elapsed_time_seconds] || 0,
        task_id: raw[:task_id]
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
      usage = raw[:usage]
      parsed_usage = if usage
        TaskUsage.new(
          total_tokens: usage[:total_tokens] || 0,
          tool_uses: usage[:tool_uses] || 0,
          duration_ms: usage[:duration_ms] || 0
        )
      end

      TaskNotificationMessage.new(
        uuid: raw[:uuid] || "",
        session_id: raw[:session_id] || "",
        task_id: raw[:task_id] || "",
        status: raw[:status] || "unknown",
        output_file: raw[:output_file] || "",
        summary: raw[:summary] || "",
        tool_use_id: raw[:tool_use_id],
        usage: parsed_usage
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
        task_type: raw[:task_type],
        prompt: raw[:prompt]
      )
    end

    def parse_task_progress_message(raw)
      TaskProgressMessage.new(
        uuid: raw[:uuid] || "",
        session_id: raw[:session_id] || "",
        task_id: raw[:task_id] || "",
        tool_use_id: raw[:tool_use_id],
        description: raw[:description] || "",
        usage: raw[:usage],
        last_tool_name: raw[:last_tool_name],
        summary: raw[:summary]
      )
    end

    def parse_elicitation_complete_message(raw)
      ElicitationCompleteMessage.new(
        uuid: raw[:uuid] || "",
        session_id: raw[:session_id] || "",
        mcp_server_name: raw[:mcp_server_name] || "",
        elicitation_id: raw[:elicitation_id] || ""
      )
    end

    def parse_local_command_output_message(raw)
      LocalCommandOutputMessage.new(
        uuid: raw[:uuid] || "",
        session_id: raw[:session_id] || "",
        content: raw[:content] || ""
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
