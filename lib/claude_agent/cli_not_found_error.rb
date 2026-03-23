# frozen_string_literal: true

module ClaudeAgent
  # Raised when the Claude Code CLI cannot be found
  class CLINotFoundError < Error
    def initialize(message = "Claude Code CLI not found. Please install it first.")
      super
    end
  end
end
