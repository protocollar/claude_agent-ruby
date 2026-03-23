# frozen_string_literal: true

module ClaudeAgent
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
  class PromptSuggestionMessage < ImmutableRecord
    include Message

    attribute :suggestion
    attribute :uuid, default: nil
    attribute :session_id, default: nil

    def type
      :prompt_suggestion
    end
  end
end
