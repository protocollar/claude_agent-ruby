# frozen_string_literal: true

require "logger"

module ClaudeAgent
  # Null logger that discards all output with zero overhead.
  #
  # All log methods return +true+ immediately without performing any I/O.
  # This is the default logger, ensuring logging adds no cost when not configured.
  #
  # @example
  #   logger = ClaudeAgent::NullLogger.new
  #   logger.info("transport") { "This is discarded" }  # => true
  #
  class NullLogger < Logger
    def initialize
      super(File::NULL)
      @level = Logger::DEBUG
    end

    def add(_severity = nil, _message = nil, _progname = nil)
      true
    end

    def debug(...)  = true
    def info(...)   = true
    def warn(...)   = true
    def error(...)  = true
    def fatal(...)  = true
    def unknown(...) = true

    def debug?  = false
    def info?   = false
    def warn?   = false
    def error?  = false
    def fatal?  = false
  end

  # Compact log formatter with gem name tag.
  #
  # Output format:
  #   [ClaudeAgent] [12:00:00.123] DEBUG -- transport: Spawning CLI
  #
  LOG_FORMATTER = proc do |severity, time, progname, msg|
    "[ClaudeAgent] [#{time.strftime("%H:%M:%S.%L")}] #{severity.ljust(5)} -- #{progname}: #{msg}\n"
  end

  class << self
    # Module-level logger used by all components unless overridden per-query.
    #
    # Defaults to {NullLogger} for zero overhead. Set to any +Logger+-compatible
    # instance to enable logging.
    #
    # @return [Logger]
    #
    # @example
    #   ClaudeAgent.logger = Logger.new($stderr, level: :info)
    #
    def logger
      @logger ||= default_logger
    end

    # Set the module-level logger.
    #
    # @param logger [Logger] A Logger-compatible instance
    # @return [Logger]
    def logger=(logger)
      @logger = logger
    end

    # Enable debug-level logging to stderr (or a custom output).
    #
    # Convenience method for quick debugging. Creates a +Logger+ with
    # a compact formatter and DEBUG level.
    #
    # @param output [IO] Output destination (default: +$stderr+)
    # @return [Logger] The configured logger
    #
    # @example
    #   ClaudeAgent.debug!
    #   ClaudeAgent.debug!(output: $stdout)
    #   ClaudeAgent.debug!(output: File.open("debug.log", "a"))
    #
    def debug!(output: $stderr)
      self.logger = Logger.new(output, level: Logger::DEBUG).tap do |l|
        l.formatter = LOG_FORMATTER
      end
    end

    private

    def default_logger
      if ENV["CLAUDE_AGENT_DEBUG"]
        Logger.new($stderr, level: Logger::DEBUG).tap do |l|
          l.formatter = LOG_FORMATTER
        end
      else
        NullLogger.new
      end
    end
  end
end
