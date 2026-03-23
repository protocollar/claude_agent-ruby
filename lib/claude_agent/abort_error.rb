# frozen_string_literal: true

module ClaudeAgent
  # Raised when an operation is aborted/cancelled (TypeScript SDK parity)
  #
  # This error is raised when an operation is explicitly cancelled,
  # such as through a user interrupt or abort signal.
  #
  # When raised from {Client#receive_turn} or {Conversation#say},
  # carries a partial {TurnResult} with whatever was accumulated
  # before cancellation (text, tool executions, usage).
  #
  # @example Accessing partial results
  #   begin
  #     turn = conversation.say("Fix the bug")
  #   rescue ClaudeAgent::AbortError => e
  #     turn = e.partial_turn
  #     puts turn.text         # accumulated text (from stream events if needed)
  #     puts turn.tool_uses    # tools that were called before abort
  #   end
  #
  class AbortError < Error
    # @return [TurnResult, nil] Partial turn accumulated before abort
    attr_reader :partial_turn

    def initialize(message = "Operation was aborted", partial_turn: nil)
      @partial_turn = partial_turn
      super(message)
    end
  end
end
