# frozen_string_literal: true

module ClaudeAgent
  # Raised when connection to CLI fails
  class CLIConnectionError < Error
    def initialize(message = "Failed to connect to Claude Code CLI")
      super
    end
  end
end
