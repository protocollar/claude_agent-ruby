# frozen_string_literal: true

module ClaudeAgent
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
  class RateLimitEvent < ImmutableRecord
    include Message

    attribute :rate_limit_info
    attribute :uuid, default: nil
    attribute :session_id, default: nil

    def type
      :rate_limit_event
    end

    # Get the rate limit status
    # @return [String, nil]
    def status
      rate_limit_info[:status]
    end
  end
end
