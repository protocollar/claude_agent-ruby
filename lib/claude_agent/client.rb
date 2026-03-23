# frozen_string_literal: true

module ClaudeAgent
  # Interactive, bidirectional client for Claude Code CLI
  #
  # Unlike {ClaudeAgent.query}, the Client provides:
  # - Multiple conversation turns
  # - Streaming responses
  # - Ability to interrupt operations
  # - Dynamic permission and model changes
  # - File checkpointing and rewind
  #
  # @example Basic usage
  #   client = ClaudeAgent::Client.new
  #   client.connect
  #   client.send_message("Hello!")
  #   client.receive_response.each { |msg| puts msg }
  #   client.disconnect
  #
  # @example With block (auto-disconnect)
  #   ClaudeAgent::Client.open do |client|
  #     client.send_message("Help me write a function")
  #     client.receive_response.each { |msg| puts msg }
  #
  #     client.send_message("Now add tests")
  #     client.receive_response.each { |msg| puts msg }
  #   end
  #
  # @example With initial prompt
  #   ClaudeAgent::Client.open(prompt: "You are a helpful coding assistant") do |client|
  #     client.receive_response.each { |msg| puts msg }
  #   end
  #
  class Client
    include Commands

    attr_reader :options, :transport, :server_info, :cumulative_usage, :event_handler, :permission_queue

    # Open a client with automatic cleanup
    #
    # @param options [Options, nil] Configuration options
    # @param transport [Transport::Base, nil] Custom transport
    # @param prompt [String, nil] Initial prompt
    # @yield [Client] Connected client
    # @return [Object] Result of block
    def self.open(options: nil, transport: nil, prompt: nil)
      client = new(options: options, transport: transport)
      begin
        client.connect(prompt: prompt)
        yield client
      ensure
        client.disconnect
      end
    end

    # Create a new client
    #
    # @param options [Options, nil] Configuration options
    # @param transport [Transport::Base, nil] Custom transport (default: Subprocess)
    def initialize(options: nil, transport: nil)
      @options = options || Options.new
      @transport = transport || Transport::Subprocess.new(options: @options)
      @protocol = nil
      @server_info = nil
      @connected = false
      @cumulative_usage = CumulativeUsage.new
      @event_handler = EventHandler.new
      @permission_queue = PermissionQueue.new
    end

    # Connect to the CLI
    #
    # @param prompt [String, nil] Initial prompt to send
    # @return [void]
    def connect(prompt: nil)
      raise CLIConnectionError, "Already connected" if @connected

      logger.info("client") { "Connecting" }
      @protocol = ControlProtocol.new(transport: @transport, options: @options)
      @protocol.permission_queue = @permission_queue
      @server_info = @protocol.start(streaming: true)
      @connected = true
      logger.info("client") { "Connected" }

      send_message(prompt) if prompt
    end

    # Disconnect from the CLI
    #
    # @return [void]
    def disconnect
      return unless @connected

      logger.info("client") { "Disconnecting" }
      @permission_queue.drain!(reason: "Client disconnected")
      @protocol&.stop
      @protocol = nil
      @connected = false
    end

    # Check if client is connected
    #
    # @return [Boolean]
    def connected?
      @connected
    end

    # Send a message to Claude
    #
    # @param content [String, Array] Message content
    # @param session_id [String] Session ID (for multi-session support)
    # @param uuid [String, nil] Message UUID for file checkpointing
    # @return [void]
    def send_message(content, session_id: "default", uuid: nil)
      require_connection!
      logger.debug("client") { "Sending message (session=#{session_id})" }
      @protocol.send_user_message(content, session_id: session_id, uuid: uuid)
    end

    # Alias for send_message
    alias_method :query, :send_message

    # Receive all messages (blocks until connection closes)
    #
    # @yield [Message] Received messages
    # @return [Enumerator<Message>] If no block given
    def receive_messages
      require_connection!

      if block_given?
        @protocol.each_message do |message|
          @cumulative_usage.track(message)
          yield message
        end
      else
        enum_for(:receive_messages)
      end
    end

    # Receive messages until a ResultMessage is received
    #
    # @yield [Message] Received messages
    # @return [Enumerator<Message>] If no block given
    def receive_response
      require_connection!

      if block_given?
        @protocol.receive_response do |message|
          @cumulative_usage.track(message)
          yield message
        end
      else
        enum_for(:receive_response)
      end
    end

    # Register an event handler
    #
    # Handlers persist across turns and fire automatically during
    # {#receive_turn} and {#send_and_receive}.
    #
    # See {EventHandler} for the full event hierarchy:
    # - +:message+ — catch-all for every message
    # - Type-based — +:assistant+, +:stream_event+, +:status+, etc.
    # - Decomposed — +:text+, +:thinking+, +:tool_use+, +:tool_result+
    #
    # @param event [Symbol] Event name (see {EventHandler::EVENTS})
    # @yield Event-specific arguments
    # @return [self]
    #
    # @example
    #   client.on(:text) { |text| print text }
    #   client.on(:tool_use) { |tool| show_spinner(tool) }
    #   client.on(:stream_event) { |evt| handle_stream(evt) }
    #
    def on(event, &block)
      @event_handler.on(event, &block)
      self
    end

    # Generates on_* convenience methods for all known events.
    # See {EventHandler::EVENTS} for the complete list.
    EventHandler::EVENTS.each do |event|
      define_method(:"on_#{event}") { |&block| on(event, &block) }
    end

    # Receive messages until a ResultMessage, accumulating into a TurnResult
    #
    # Dispatches events to registered handlers (see {#on}).
    # On abort, raises {AbortError} with the partial {TurnResult} attached.
    #
    # @yield [Message] Each message as it arrives (optional)
    # @return [TurnResult] The completed turn
    # @raise [AbortError] If abort signal is triggered (with partial_turn attached)
    def receive_turn
      require_connection!

      turn = TurnResult.new
      begin
        receive_response do |message|
          turn << message
          @event_handler.handle(message)
          yield message if block_given?
        end
      rescue AbortError => e
        raise AbortError.new(e.message, partial_turn: turn)
      end
      @event_handler.reset!
      turn
    end

    # Send a message and receive the complete turn result
    #
    # Combines {#send_message} and {#receive_turn} into a single call.
    #
    # @param content [String, Array] Message content
    # @param session_id [String] Session ID
    # @param uuid [String, nil] Message UUID for file checkpointing
    # @yield [Message] Each message as it arrives (optional)
    # @return [TurnResult] The completed turn
    #
    # @example Simple
    #   turn = client.send_and_receive("Fix the bug")
    #   puts turn.text
    #   puts "Cost: $#{turn.cost}"
    #
    # @example With streaming
    #   turn = client.send_and_receive("Fix the bug") do |msg|
    #     case msg
    #     when ClaudeAgent::AssistantMessage
    #       print msg.text
    #     end
    #   end
    #
    def send_and_receive(content, session_id: "default", uuid: nil, &block)
      send_message(content, session_id: session_id, uuid: uuid)
      receive_turn(&block)
    end

    # Stream user input from an enumerable (TypeScript SDK parity)
    #
    # Sends each message from the input stream to Claude. When a block is given,
    # messages are sent in a background thread while responses are yielded.
    #
    # @param stream [Enumerable] Input stream of messages (strings, hashes, or UserMessage)
    # @param session_id [String] Default session ID for messages
    # @yield [Message] Received messages (if block given)
    # @return [void]
    # @raise [CLIConnectionError] If not connected
    # @raise [AbortError] If abort signal is triggered
    #
    # @example Without block (just send messages)
    #   client.stream_input(["Hello", "How are you?"])
    #   client.receive_response.each { |msg| puts msg }
    #
    # @example With block (concurrent send/receive)
    #   client.stream_input(["Hello", "Follow up"]) do |msg|
    #     case msg
    #     when ClaudeAgent::AssistantMessage
    #       puts msg.text
    #     when ClaudeAgent::ResultMessage
    #       puts "Done!"
    #     end
    #   end
    #
    def stream_input(stream, session_id: "default")
      require_connection!

      if block_given?
        @protocol.stream_conversation(stream, session_id: session_id) do |message|
          @cumulative_usage.track(message)
          yield message
        end
      else
        @protocol.stream_input(stream, session_id: session_id)
      end
    end

    # Interrupt the current operation
    #
    # @return [void]
    def interrupt
      require_connection!

      @protocol.interrupt
    end

    # Abort all pending operations (TypeScript SDK parity)
    #
    # This method:
    # 1. Triggers the abort controller (if configured)
    # 2. Aborts the protocol and terminates the transport
    #
    # @param reason [String, nil] Reason for aborting
    # @return [void]
    def abort!(reason = nil)
      return unless @connected

      @permission_queue.drain!(reason: reason || "Operation aborted")
      @options.abort_controller&.abort(reason)
      @protocol&.abort!
    end

    # Non-blocking poll for the next pending permission request.
    #
    # Returns the next {PermissionRequest} from the queue, or nil if
    # no requests are pending. Call {PermissionRequest#allow!} or
    # {PermissionRequest#deny!} to resolve it.
    #
    # @return [PermissionRequest, nil] The next pending request, or nil
    #
    # @example UI poll loop
    #   if request = client.pending_permission
    #     show_permission_dialog(request)
    #   end
    #
    def pending_permission
      @permission_queue.poll
    end

    # Check if there are any pending permission requests.
    #
    # @return [Boolean]
    def pending_permissions?
      !@permission_queue.empty?
    end

    private

    def logger
      @options.effective_logger
    end

    def require_connection!
      raise CLIConnectionError, "Not connected" unless @connected
    end
  end
end
