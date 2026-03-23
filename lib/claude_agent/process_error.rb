# frozen_string_literal: true

module ClaudeAgent
  # Raised when the CLI process exits with an error
  class ProcessError < Error
    attr_reader :exit_code, :stderr

    def initialize(message = "CLI process failed", exit_code: nil, stderr: nil)
      @exit_code = exit_code
      @stderr = stderr
      full_message = message
      full_message += " (exit code: #{exit_code})" if exit_code
      full_message += "\nStderr: #{stderr}" if stderr && !stderr.empty?
      super(full_message)
    end
  end
end
