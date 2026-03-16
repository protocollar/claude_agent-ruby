# frozen_string_literal: true

module ClaudeAgent
  # Base error class for all ClaudeAgent errors
  class Error < StandardError; end

  # Raised when the Claude Code CLI cannot be found
  class CLINotFoundError < Error
    def initialize(message = "Claude Code CLI not found. Please install it first.")
      super
    end
  end

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

  # Raised when connection to CLI fails
  class CLIConnectionError < Error
    def initialize(message = "Failed to connect to Claude Code CLI")
      super
    end
  end

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

  # Raised when JSON parsing fails
  class JSONDecodeError < Error
    attr_reader :raw_content

    def initialize(message = "Failed to decode JSON", raw_content: nil)
      @raw_content = raw_content
      full_message = message
      full_message += "\nContent: #{raw_content[0..200]}..." if raw_content
      super(full_message)
    end
  end

  # Raised when message parsing fails
  class MessageParseError < Error
    attr_reader :raw_message

    def initialize(message = "Failed to parse message", raw_message: nil)
      @raw_message = raw_message
      full_message = message
      full_message += "\nRaw message: #{raw_message.inspect[0..200]}" if raw_message
      super(full_message)
    end
  end

  # Raised when a control protocol request times out
  class TimeoutError < Error
    attr_reader :request_id, :timeout_seconds

    def initialize(message = "Request timed out", request_id: nil, timeout_seconds: nil)
      @request_id = request_id
      @timeout_seconds = timeout_seconds
      full_message = message
      full_message += " (request_id: #{request_id})" if request_id
      full_message += " after #{timeout_seconds}s" if timeout_seconds
      super(full_message)
    end
  end

  # Raised when an invalid option is provided
  class ConfigurationError < Error; end

  # Raised when a resource is not found (Stripe convention)
  class NotFoundError < Error; end

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
