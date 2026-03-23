# frozen_string_literal: true

module ClaudeAgent
  # Raised when a resource is not found (Stripe convention)
  class NotFoundError < Error; end
end
