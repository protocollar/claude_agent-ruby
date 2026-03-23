# frozen_string_literal: true

module ClaudeAgent
  # Raised when the CLI version is below minimum required
  class CLIVersionError < Error
    MINIMUM_VERSION = "2.0.0"

    def initialize(found_version = nil)
      message = if found_version
        "Claude Code CLI version #{found_version} is below minimum required version #{MINIMUM_VERSION}"
      else
        "Could not determine Claude Code CLI version. Minimum required: #{MINIMUM_VERSION}"
      end
      super(message)
    end
  end
end
