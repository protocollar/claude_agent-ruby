# frozen_string_literal: true

require "json"
require "securerandom"

require_relative "control_protocol/primitives"
require_relative "control_protocol/lifecycle"
require_relative "control_protocol/messaging"
require_relative "control_protocol/commands"
require_relative "control_protocol/request_handling"

module ClaudeAgent
  # Handles the control protocol for bidirectional communication with Claude Code CLI
  #
  # The control protocol enables:
  # - Initialization handshake with hook registration
  # - Tool permission callbacks (can_use_tool)
  # - Hook callbacks (PreToolUse, PostToolUse, etc.)
  # - MCP message routing for SDK servers
  # - Dynamic permission mode and model changes
  # - Interrupt and file rewind operations
  #
  # @example Basic usage
  #   protocol = ControlProtocol.new(transport: transport, options: options)
  #   protocol.start
  #   protocol.each_message { |msg| process(msg) }
  #
  # State ownership across modules:
  #
  # Owned by Lifecycle:
  #   @running, @reader_thread
  #
  # Owned by RequestHandling:
  #   @hook_callbacks
  #
  # Owned by Primitives:
  #   write_message, read helpers (stateless)
  #
  # Owned by Commands:
  #   interrupt, rewind (stateless, uses @transport)
  #
  # Shared (initialized here, used by multiple modules):
  #   @transport, @options, @parser, @server_info
  #   @request_counter, @pending_requests, @pending_results (Primitives + RequestHandling)
  #   @mutex, @condition (Primitives + Lifecycle + RequestHandling)
  #   @message_queue (Lifecycle + Messaging)
  #   @abort_signal (Lifecycle + Messaging)
  #   @permission_queue (RequestHandling, set externally by Client)
  #
  class ControlProtocol
    DEFAULT_TIMEOUT = 60
    REQUEST_ID_PREFIX = "req"

    # Mapping of Ruby keys to CLI keys for hook responses
    # Handles special cases where Ruby uses trailing underscore for reserved words
    HOOK_RESPONSE_KEYS = {
      continue_: "continue",
      continue: "continue",
      async_: "async",
      async: "async",
      async_timeout: "asyncTimeout",
      suppress_output: "suppressOutput",
      stop_reason: "stopReason",
      decision: "decision",
      system_message: "systemMessage",
      reason: "reason"
    }.freeze

    include Primitives
    include Lifecycle
    include Messaging
    include Commands
    include RequestHandling

    attr_reader :transport, :options, :server_info
    attr_accessor :permission_queue

    # @param transport [Transport::Base] Transport for communication
    # @param options [Options] Configuration options
    def initialize(transport:, options: nil)
      @transport = transport
      @options = options || Options.new
      @parser = MessageParser.new(logger: @options.effective_logger)
      @server_info = nil

      # Control protocol state
      @request_counter = 0
      @pending_requests = {}
      @pending_results = {}
      @hook_callbacks = {}

      # Threading primitives
      @mutex = Mutex.new
      @condition = ConditionVariable.new

      # Reader thread
      @reader_thread = nil
      @message_queue = Queue.new
      @running = false

      # Abort signal from options
      @abort_signal = options&.abort_signal
      @abort_signal&.on_abort { @message_queue.push(:done) }
    end

    private

    def logger
      @options.effective_logger
    end
  end
end
