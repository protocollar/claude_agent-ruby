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
    attr_reader :options, :transport, :server_info

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
    end

    # Connect to the CLI
    #
    # @param prompt [String, nil] Initial prompt to send
    # @return [void]
    def connect(prompt: nil)
      raise CLIConnectionError, "Already connected" if @connected

      ENV["CLAUDE_CODE_ENTRYPOINT"] = "sdk-rb-client"

      @protocol = ControlProtocol.new(transport: @transport, options: @options)
      @server_info = @protocol.start(streaming: true)
      @connected = true

      send_message(prompt) if prompt
    end

    # Disconnect from the CLI
    #
    # @return [void]
    def disconnect
      return unless @connected

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
      @protocol.send_user_message(content, session_id: session_id, uuid: uuid)
    end

    # Alias for send_message
    alias_method :query, :send_message

    # Receive all messages (blocks until connection closes)
    #
    # @yield [Message] Received messages
    # @return [Enumerator<Message>] If no block given
    def receive_messages(&block)
      require_connection!

      @protocol.each_message(&block)
    end

    # Receive messages until a ResultMessage is received
    #
    # @yield [Message] Received messages
    # @return [Enumerator<Message>] If no block given
    def receive_response(&block)
      require_connection!

      @protocol.receive_response(&block)
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
    def stream_input(stream, session_id: "default", &block)
      require_connection!

      if block_given?
        @protocol.stream_conversation(stream, session_id: session_id, &block)
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

    private

    def require_connection!
      raise CLIConnectionError, "Not connected" unless @connected
    end
  end
end
