# frozen_string_literal: true

module ClaudeAgent
  # Extended thinking content block
  #
  # @example
  #   block = ThinkingBlock.new(thinking: "Let me consider...", signature: "abc123")
  #   block.thinking # => "Let me consider..."
  #
  class ThinkingBlock < ImmutableRecord
    attribute :thinking
    attribute :signature

    def type
      :thinking
    end

    def to_h
      { type: "thinking", thinking: thinking, signature: signature }
    end
  end
end
