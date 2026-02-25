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

      ENV["CLAUDE_CODE_ENTRYPOINT"] = "sdk-rb-client"

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
    # @param event [Symbol] Event name (:message, :text, :thinking, :tool_use, :tool_result, :result)
    # @yield Event-specific arguments
    # @return [self]
    #
    # @example
    #   client.on(:text) { |text| print text }
    #   client.on(:tool_use) { |tool| show_spinner(tool) }
    #
    def on(event, &block)
      @event_handler.on(event, &block)
      self
    end

    # @!method on_text(&block)
    #   Register a handler for assistant text content
    #   @yield [String] Text from the AssistantMessage
    #   @return [self]

    # @!method on_thinking(&block)
    #   Register a handler for assistant thinking content
    #   @yield [String] Thinking from the AssistantMessage
    #   @return [self]

    # @!method on_tool_use(&block)
    #   Register a handler for tool use requests
    #   @yield [ToolUseBlock, ServerToolUseBlock] The tool use block
    #   @return [self]

    # @!method on_tool_result(&block)
    #   Register a handler for tool results, paired with the original request
    #   @yield [ToolResultBlock, ToolUseBlock|nil] Result block and matched tool use
    #   @return [self]

    # @!method on_result(&block)
    #   Register a handler for the final ResultMessage
    #   @yield [ResultMessage] The result
    #   @return [self]

    # @!method on_message(&block)
    #   Register a handler for every message (catch-all)
    #   @yield [message] Any message object
    #   @return [self]

    %i[message text thinking tool_use tool_result result].each do |event|
      define_method(:"on_#{event}") { |&block| on(event, &block) }
    end

    # Receive messages until a ResultMessage, accumulating into a TurnResult
    #
    # Dispatches events to registered handlers (see {#on}).
    #
    # @yield [Message] Each message as it arrives (optional)
    # @return [TurnResult] The completed turn
    def receive_turn
      require_connection!

      turn = TurnResult.new
      receive_response do |message|
        turn << message
        @event_handler.handle(message)
        yield message if block_given?
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

    # Change the permission mode
    #
    # @param mode [String] New permission mode
    # @return [Hash] Response
    def set_permission_mode(mode)
      require_connection!

      @protocol.set_permission_mode(mode)
    end

    # Change the model
    #
    # @param model [String, nil] New model name (nil to use default)
    # @return [Hash] Response
    def set_model(model)
      require_connection!

      @protocol.set_model(model)
    end

    # Rewind files to the state at a specific user message
    #
    # @param user_message_id [String] UUID of the user message to rewind to
    # @param dry_run [Boolean] If true, preview changes without modifying files
    # @return [RewindFilesResult] Result with rewind information
    def rewind_files(user_message_id, dry_run: false)
      require_connection!

      @protocol.rewind_files(user_message_id, dry_run: dry_run)
    end

    # Set maximum thinking tokens (TypeScript SDK parity)
    #
    # @param tokens [Integer, nil] Max thinking tokens (nil to reset)
    # @return [Hash] Response
    def set_max_thinking_tokens(tokens)
      require_connection!

      @protocol.set_max_thinking_tokens(tokens)
    end

    # Get available slash commands (TypeScript SDK parity)
    #
    # @return [Array<SlashCommand>]
    def supported_commands
      require_connection!

      @protocol.supported_commands
    end

    # Get available models (TypeScript SDK parity)
    #
    # @return [Array<ModelInfo>]
    def supported_models
      require_connection!

      @protocol.supported_models
    end

    # Get MCP server status (TypeScript SDK parity)
    #
    # @return [Array<McpServerStatus>]
    def mcp_server_status
      require_connection!

      @protocol.mcp_server_status
    end

    # Get account information (TypeScript SDK parity)
    #
    # @return [AccountInfo]
    def account_info
      require_connection!

      @protocol.account_info
    end

    # Get full initialization result (TypeScript SDK parity)
    #
    # @return [InitializationResult]
    def initialization_result
      require_connection!

      @protocol.initialization_result
    end

    # Stop a running background task (TypeScript SDK parity)
    #
    # Sends a stop signal to a running task. A task_notification message
    # with status 'stopped' will be emitted when the task stops.
    #
    # @param task_id [String] The task ID from task_notification events
    # @return [void]
    #
    # @example
    #   client.stop_task("task-123")
    #
    def stop_task(task_id)
      require_connection!

      @protocol.stop_task(task_id)
    end

    # Apply flag settings (TypeScript SDK v0.2.50 parity)
    #
    # Merges the provided settings into the flag settings layer.
    #
    # @param settings [Hash] Settings to merge into the flag layer
    # @return [Hash] Response from the CLI
    #
    # @example
    #   client.apply_flag_settings({ "model" => "claude-sonnet-4-5-20250514" })
    #
    def apply_flag_settings(settings)
      require_connection!

      @protocol.apply_flag_settings(settings)
    end

    # Dynamically set MCP servers for this session (TypeScript SDK parity)
    #
    # This replaces the current set of dynamically-added MCP servers.
    # Servers that are removed will be disconnected, and new servers will be connected.
    #
    # @param servers [Hash] Map of server name to configuration
    # @return [McpSetServersResult] Result with added, removed, and errors
    #
    # @example
    #   result = client.set_mcp_servers({
    #     "my-server" => { type: "stdio", command: "node", args: ["server.js"] }
    #   })
    #   puts "Added: #{result.added}"
    #   puts "Removed: #{result.removed}"
    #
    def set_mcp_servers(servers)
      require_connection!

      @protocol.set_mcp_servers(servers)
    end

    # Reconnect to an MCP server (TypeScript SDK parity)
    #
    # Attempts to reconnect to a disconnected or errored MCP server.
    #
    # @param server_name [String] Name of the MCP server to reconnect
    # @return [Hash] Response from the CLI
    #
    # @example
    #   client.mcp_reconnect("my-server")
    #
    def mcp_reconnect(server_name)
      require_connection!

      @protocol.mcp_reconnect(server_name)
    end

    # Enable or disable an MCP server (TypeScript SDK parity)
    #
    # Toggles an MCP server on or off without removing its configuration.
    #
    # @param server_name [String] Name of the MCP server to toggle
    # @param enabled [Boolean] Whether to enable (true) or disable (false) the server
    # @return [Hash] Response from the CLI
    #
    # @example Enable a server
    #   client.mcp_toggle("my-server", enabled: true)
    #
    # @example Disable a server
    #   client.mcp_toggle("my-server", enabled: false)
    #
    def mcp_toggle(server_name, enabled:)
      require_connection!

      @protocol.mcp_toggle(server_name, enabled: enabled)
    end

    # Initiate OAuth authentication for an MCP server (TypeScript SDK v0.2.52 parity)
    #
    # @param server_name [String] Name of the MCP server to authenticate
    # @return [Hash] Response from the CLI
    #
    # @example
    #   client.mcp_authenticate("my-remote-server")
    #
    def mcp_authenticate(server_name)
      require_connection!

      @protocol.mcp_authenticate(server_name)
    end

    # Clear stored auth credentials for an MCP server (TypeScript SDK v0.2.52 parity)
    #
    # @param server_name [String] Name of the MCP server to clear auth for
    # @return [Hash] Response from the CLI
    #
    # @example
    #   client.mcp_clear_auth("my-remote-server")
    #
    def mcp_clear_auth(server_name)
      require_connection!

      @protocol.mcp_clear_auth(server_name)
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
