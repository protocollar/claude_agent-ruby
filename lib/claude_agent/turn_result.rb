# frozen_string_literal: true

module ClaudeAgent
  # Represents a complete agent turn — everything from sending a prompt
  # to receiving the final ResultMessage.
  #
  # Accumulates messages as they flow through and provides convenient
  # accessors for text, tool use, usage data, and more. Eliminates the
  # 5+ message type `case` statement that every app rewrites.
  #
  # @example Via Client
  #   turn = client.send_and_receive("Fix the bug in auth.rb")
  #   puts turn.text
  #   puts "Cost: $#{turn.cost}"
  #   puts "Tools used: #{turn.tool_uses.map(&:display_label).join(", ")}"
  #
  # @example With streaming block
  #   turn = client.send_and_receive("Fix the bug") do |msg|
  #     case msg
  #     when ClaudeAgent::AssistantMessage
  #       print msg.text
  #     end
  #   end
  #   puts "\nDone! #{turn.tool_uses.size} tools used"
  #
  # @example Via one-shot query
  #   turn = ClaudeAgent.query_turn(prompt: "What is 2+2?")
  #   puts turn.text
  #
  class TurnResult
    # All messages received during this turn
    # @return [Array<Message>]
    attr_reader :messages

    def initialize
      @messages = []
      @result = nil
      @streamed_text = +""
    end

    # Append a message to this turn
    #
    # @param message [Message] Any SDK message
    # @return [self]
    def <<(message)
      @messages << message
      @result = message if message.is_a?(ResultMessage)

      # Accumulate streaming text deltas for reliable text access on abort
      if message.is_a?(StreamEvent)
        delta = message.delta_text
        @streamed_text << delta if delta
      end

      self
    end

    # The final ResultMessage, or nil if the turn is still in progress
    # @return [ResultMessage, nil]
    def result
      @result
    end

    # Whether a ResultMessage has been received
    # @return [Boolean]
    def complete?
      !@result.nil?
    end

    # --- Text & Thinking ---

    # All text content from the turn.
    #
    # Returns text from AssistantMessages when available (canonical source).
    # Falls back to accumulated streaming deltas when assistant messages
    # have no text (e.g., turn was aborted before AssistantMessage arrived).
    #
    # @return [String]
    def text
      t = assistant_messages.map(&:text).join
      if t.empty? && !@streamed_text.empty?
        @streamed_text.dup.freeze
      else
        t
      end
    end

    # All thinking content concatenated across assistant messages
    # @return [String]
    def thinking
      assistant_messages.map(&:thinking).join
    end

    # --- Tool Use ---

    # All tool use blocks across all assistant messages
    # @return [Array<ToolUseBlock, ServerToolUseBlock>]
    def tool_uses
      assistant_messages.flat_map { |m| m.content.select { |b| b.is_a?(ToolUseBlock) || b.is_a?(ServerToolUseBlock) } }
    end

    # All tool result blocks from user messages (system-generated tool responses)
    # @return [Array<ToolResultBlock, ServerToolResultBlock>]
    def tool_results
      user_messages
        .select { |m| m.content.is_a?(Array) }
        .flat_map { |m| m.content.select { |b| b.is_a?(ToolResultBlock) || b.is_a?(ServerToolResultBlock) } }
    end

    # Tool use/result pairs matched by ID
    #
    # Each entry is a Hash with:
    # - `:tool_use` — the ToolUseBlock or ServerToolUseBlock
    # - `:tool_result` — the matching ToolResultBlock/ServerToolResultBlock (nil if not yet received)
    #
    # @return [Array<Hash>]
    def tool_executions
      results_by_id = tool_results.each_with_object({}) { |r, h| h[r.tool_use_id] = r }
      tool_uses.map do |tool_use|
        { tool_use: tool_use, tool_result: results_by_id[tool_use.id] }
      end
    end

    # --- Result Accessors ---

    # Token usage from the ResultMessage
    # @return [Hash, nil]
    def usage
      @result&.usage
    end

    # Total cost in USD
    # @return [Float, nil]
    def cost
      @result&.total_cost_usd
    end

    # Wall-clock duration in milliseconds
    # @return [Integer, nil]
    def duration_ms
      @result&.duration_ms
    end

    # API-only duration in milliseconds
    # @return [Integer, nil]
    def duration_api_ms
      @result&.duration_api_ms
    end

    # Session ID for resumption
    # @return [String, nil]
    def session_id
      @result&.session_id
    end

    # Number of turns in the session
    # @return [Integer, nil]
    def num_turns
      @result&.num_turns
    end

    # Why the model stopped generating
    # @return [String, nil]
    def stop_reason
      @result&.stop_reason
    end

    # Model used for this turn (from first assistant message)
    # @return [String, nil]
    def model
      assistant_messages.first&.model
    end

    # Per-model usage breakdown
    # @return [Hash, nil]
    def model_usage
      @result&.model_usage
    end

    # Structured output (if requested via options)
    # @return [Object, nil]
    def structured_output
      @result&.structured_output
    end

    # Tools that were denied by permission callbacks
    # @return [Array<SDKPermissionDenial>]
    def permission_denials
      @result&.permission_denials || []
    end

    # Errors from the result
    # @return [Array<String>]
    def errors
      @result&.errors || []
    end

    # --- Status ---

    # Whether the turn completed successfully
    # @return [Boolean]
    def success?
      @result&.success? || false
    end

    # Whether the turn ended with an error
    # @return [Boolean]
    def error?
      @result&.error? || false
    end

    # The result subtype (e.g. "success", "error_max_turns")
    # @return [String, nil]
    def subtype
      @result&.subtype
    end

    # --- Filtered Message Access ---

    # All AssistantMessages in this turn
    # @return [Array<AssistantMessage>]
    def assistant_messages
      @messages.select { |m| m.is_a?(AssistantMessage) }
    end

    # All UserMessages in this turn (including system-generated tool result messages)
    # @return [Array<UserMessage, UserMessageReplay>]
    def user_messages
      @messages.select { |m| m.is_a?(UserMessage) || m.is_a?(UserMessageReplay) }
    end

    # All StreamEvents in this turn
    # @return [Array<StreamEvent>]
    def stream_events
      @messages.select { |m| m.is_a?(StreamEvent) }
    end

    # All content blocks across all assistant messages
    # @return [Array<TextBlock, ThinkingBlock, ToolUseBlock, ...>]
    def content_blocks
      assistant_messages.flat_map(&:content)
    end

    # --- Inspection ---

    def inspect
      status = complete? ? (success? ? "success" : "error") : "in_progress"
      parts = [ "#<#{self.class} status=#{status}" ]
      parts << "messages=#{@messages.size}"
      parts << "text=#{text.length}chars" unless text.empty?
      parts << "tools=#{tool_uses.size}" unless tool_uses.empty?
      parts << "cost=$#{cost}" if cost
      parts << "duration=#{duration_ms}ms" if duration_ms
      "#{parts.join(" ")}>"
    end
  end
end
