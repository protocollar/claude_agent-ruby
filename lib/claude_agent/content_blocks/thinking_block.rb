# frozen_string_literal: true

module ClaudeAgent
  # Extended thinking content block
  #
  # @example
  #   block = ThinkingBlock.new(thinking: "Let me consider...", signature: "abc123")
  #   block.thinking # => "Let me consider..."
  #
  ThinkingBlock = Data.define(:thinking, :signature) do
    def type
      :thinking
    end

    def to_h
      { type: "thinking", thinking: thinking, signature: signature }
    end
  end
end
