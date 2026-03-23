# frozen_string_literal: true

module ClaudeAgent
  # Raised when a control protocol request times out
  class TimeoutError < Error
    attr_reader :request_id, :timeout_seconds

    def initialize(message = "Request timed out", request_id: nil, timeout_seconds: nil)
      @request_id = request_id
      @timeout_seconds = timeout_seconds
      full_message = message
      full_message += " (request_id: #{request_id})" if request_id
      full_message += " after #{timeout_seconds}s" if timeout_seconds
      super(full_message)
    end
  end
end
