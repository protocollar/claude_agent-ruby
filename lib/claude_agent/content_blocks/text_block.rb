# frozen_string_literal: true

module ClaudeAgent
  # Text content block
  #
  # @example
  #   block = TextBlock.new(text: "Hello, world!")
  #   block.text # => "Hello, world!"
  #
  class TextBlock < ImmutableRecord
    attribute :text

    def type
      :text
    end

    def to_h
      { type: "text", text: text }
    end
  end
end
