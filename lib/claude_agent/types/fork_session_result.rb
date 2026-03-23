# frozen_string_literal: true

module ClaudeAgent
  # Result of forking a session (TypeScript SDK v0.2.76 parity)
  #
  # @example
  #   result = ClaudeAgent.fork_session("abc-123")
  #   puts result.session_id  # => new UUID
  #
  class ForkSessionResult < ImmutableRecord
    attribute :session_id
  end
end
