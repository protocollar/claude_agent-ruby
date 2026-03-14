# frozen_string_literal: true

module ClaudeAgent
  # Text content block
  #
  # @example
  #   block = TextBlock.new(text: "Hello, world!")
  #   block.text # => "Hello, world!"
  #
  TextBlock = Data.define(:text) do
    def type
      :text
    end

    def to_h
      { type: "text", text: text }
    end
  end
end
