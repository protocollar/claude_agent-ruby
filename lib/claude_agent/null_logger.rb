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
end
