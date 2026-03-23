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
  class StreamEvent < ImmutableRecord
    include Message

    attribute :uuid
    attribute :session_id
    attribute :event
    attribute :parent_tool_use_id, default: nil

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
end
