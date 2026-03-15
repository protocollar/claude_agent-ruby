# frozen_string_literal: true

module ClaudeAgent
  # Stream event (partial message during streaming)
  #
  # @example
  #   event = StreamEvent.new(
  #     uuid: "evt-123",
  #     session_id: "session-abc",
  #     event: {type: "content_block_delta", delta: {type: "text_delta", text: "Hello"}}
  #   )
  #
  StreamEvent = Data.define(:uuid, :session_id, :event, :parent_tool_use_id) do
    def initialize(uuid:, session_id:, event:, parent_tool_use_id: nil)
      super
    end

    def type
      :stream_event
    end

    # Get the event type from the raw event
    # @return [String, nil]
    def event_type
      event[:type]
    end

    # Text delta content, or nil if this is not a text_delta event.
    # @return [String, nil]
    def delta_text
      return nil unless event_type == "content_block_delta"
      delta = event[:delta] || event["delta"]
      return nil unless delta
      type = delta[:type] || delta["type"]
      return nil unless type == "text_delta"
      delta[:text] || delta["text"]
    end

    # The delta type (e.g. "text_delta", "thinking_delta", "input_json_delta").
    # @return [String, nil]
    def delta_type
      return nil unless event_type == "content_block_delta"
      delta = event[:delta] || event["delta"]
      return nil unless delta
      delta[:type] || delta["type"]
    end

    # Thinking delta text, or nil if this is not a thinking_delta event.
    # @return [String, nil]
    def thinking_text
      return nil unless event_type == "content_block_delta"
      delta = event[:delta] || event["delta"]
      return nil unless delta
      type = delta[:type] || delta["type"]
      return nil unless type == "thinking_delta"
      delta[:thinking] || delta["thinking"]
    end

    # Content block index within the message.
    # @return [Integer, nil]
    def content_index
      event[:index] || event["index"]
    end
  end

  # Rate limit event (TypeScript SDK v0.2.45 parity)
  #
  # Reports rate limit status and utilization information.
  #
  # @example
  #   msg = RateLimitEvent.new(
  #     uuid: "msg-123",
  #     session_id: "session-abc",
  #     rate_limit_info: {
  #       status: "allowed_warning",
  #       resetsAt: 1700000000,
  #       rateLimitType: "five_hour",
  #       utilization: 0.85,
  #       isUsingOverage: false,
  #       overageStatus: "available"
  #     }
  #   )
  #   msg.status  # => "allowed_warning"
  #
  RateLimitEvent = Data.define(:rate_limit_info, :uuid, :session_id) do
    def initialize(rate_limit_info:, uuid: nil, session_id: nil)
      super
    end

    def type
      :rate_limit_event
    end

    # Get the rate limit status
    # @return [String, nil]
    def status
      rate_limit_info[:status]
    end
  end

  # Prompt suggestion message (TypeScript SDK v0.2.47 parity)
  #
  # Contains a suggested prompt for the user.
  #
  # @example
  #   msg = PromptSuggestionMessage.new(
  #     uuid: "msg-123",
  #     session_id: "session-abc",
  #     suggestion: "Tell me about this project"
  #   )
  #
  PromptSuggestionMessage = Data.define(:uuid, :session_id, :suggestion) do
    def initialize(uuid: nil, session_id: nil, suggestion:)
      super
    end

    def type
      :prompt_suggestion
    end
  end
end
