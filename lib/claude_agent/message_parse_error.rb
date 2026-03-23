# frozen_string_literal: true

module ClaudeAgent
  # Raised when message parsing fails
  class MessageParseError < Error
    attr_reader :raw_message

    def initialize(message = "Failed to parse message", raw_message: nil)
      @raw_message = raw_message
      full_message = message
      full_message += "\nRaw message: #{raw_message.inspect[0..200]}" if raw_message
      super(full_message)
    end
  end
end
