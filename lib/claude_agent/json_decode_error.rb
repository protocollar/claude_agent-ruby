# frozen_string_literal: true

module ClaudeAgent
  # Raised when JSON parsing fails
  class JSONDecodeError < Error
    attr_reader :raw_content

    def initialize(message = "Failed to decode JSON", raw_content: nil)
      @raw_content = raw_content
      full_message = message
      full_message += "\nContent: #{raw_content[0..200]}..." if raw_content
      super(full_message)
    end
  end
end
