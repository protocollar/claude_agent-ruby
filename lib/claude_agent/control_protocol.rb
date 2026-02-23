# frozen_string_literal: true

require "json"
require "securerandom"

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
  class ControlProtocol
    DEFAULT_TIMEOUT = 60
    REQUEST_ID_PREFIX = "req"

    attr_reader :transport, :options, :server_info

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
    end

    # Start the control protocol (initialize connection)
    # @param streaming [Boolean] Whether to use streaming mode
    # @param prompt [String, nil] Initial prompt for non-streaming mode
    # @return [Hash, nil] Server info from initialization
    def start(streaming: true, prompt: nil)
      logger.info("protocol") { "Starting control protocol (streaming=#{streaming})" }
      @transport.connect(streaming: streaming, prompt: prompt)
      @running = true

      # Start background reader thread
      @reader_thread = Thread.new { reader_loop }
      logger.debug("protocol") { "Reader thread started" }

      # Always send initialize in streaming mode (Python/TypeScript SDK parity)
      if streaming
        @server_info = send_initialize
        logger.info("protocol") { "Initialize complete" }
      end

      @server_info
    end

    # Stop the control protocol
    # @return [void]
    def stop
      logger.info("protocol") { "Stopping control protocol" }
      @running = false
      @transport.end_input
      @reader_thread&.join(5)
      @transport.close
    end

    # Abort all pending operations (TypeScript SDK parity)
    #
    # This method:
    # 1. Stops the reader loop
    # 2. Fails all pending requests with AbortError
    # 3. Terminates the transport
    #
    # @return [void]
    def abort!
      @running = false

      # Fail all pending requests
      @mutex.synchronize do
        @pending_requests.each_key do |request_id|
          @pending_results[request_id] = {
            "subtype" => "error",
            "error" => "Operation aborted"
          }
        end
        @condition.broadcast
      end

      # Terminate the transport
      @transport.terminate if @transport.respond_to?(:terminate)
    end

    # Send a user message
    # @param content [String, Array] Message content
    # @param session_id [String] Session ID
    # @param uuid [String, nil] Message UUID for file checkpointing
    # @return [void]
    def send_user_message(content, session_id: "default", uuid: nil)
      message = {
        type: "user",
        message: { role: "user", content: content },
        session_id: session_id
      }
      message[:uuid] = uuid if uuid
      write_message(message)
    end

    # Iterate over incoming messages (SDK messages only, not control)
    # @yield [Message] Parsed message objects
    # @return [Enumerator] If no block given
    # @raise [AbortError] If abort signal is triggered
    def each_message
      return enum_for(:each_message) unless block_given?

      while @running || !@message_queue.empty?
        # Check abort signal
        @abort_signal&.check!

        begin
          raw = @message_queue.pop(true)
          message = @parser.parse(raw)
          yield message
        rescue ThreadError
          # Queue empty, wait a bit
          sleep 0.01
        rescue AbortError
          # Re-raise abort errors
          raise
        rescue => e
          logger.warn("protocol") { "Message parse error: #{e.message}" }
        end
      end
    end

    # Receive messages until a ResultMessage is received
    # @yield [Message] Parsed message objects
    # @return [Enumerator] If no block given
    def receive_response
      return enum_for(:receive_response) unless block_given?

      each_message do |message|
        yield message
        break if message.is_a?(ResultMessage)
      end
    end

    # Stream user input from an enumerable (TypeScript SDK parity)
    #
    # Sends each message from the input stream to Claude. Messages can be:
    # - String: Sent as user message content
    # - Hash: Must have :content key, optionally :session_id and :uuid
    # - UserMessage: Sent directly
    #
    # @param stream [Enumerable] Input stream of messages
    # @param session_id [String] Default session ID for messages
    # @return [void]
    # @raise [AbortError] If abort signal is triggered
    #
    # @example With strings
    #   protocol.stream_input(["Hello", "How are you?"])
    #
    # @example With hashes
    #   protocol.stream_input([
    #     { content: "Hello", uuid: "msg-1" },
    #     { content: "Follow up", session_id: "custom" }
    #   ])
    #
    def stream_input(stream, session_id: "default")
      stream.each do |message|
        # Check abort signal before each message
        @abort_signal&.check!

        case message
        when String
          send_user_message(message, session_id: session_id)
        when Hash
          content = message[:content] || message["content"]
          msg_session = message[:session_id] || message["session_id"] || session_id
          uuid = message[:uuid] || message["uuid"]
          send_user_message(content, session_id: msg_session, uuid: uuid)
        when UserMessage, UserMessageReplay
          send_user_message(message.content, session_id: message.session_id || session_id, uuid: message.uuid)
        else
          raise ArgumentError, "Unknown message type in stream: #{message.class}"
        end
      end
    end

    # Stream user input and receive responses (TypeScript SDK parity)
    #
    # Sends messages from the input stream in a background thread while
    # yielding responses in the foreground. This enables concurrent input/output.
    #
    # @param stream [Enumerable] Input stream of messages
    # @param session_id [String] Default session ID for messages
    # @yield [Message] Received messages
    # @return [Enumerator] If no block given
    # @raise [AbortError] If abort signal is triggered
    #
    # @example
    #   messages = ["Hello", "Tell me more"]
    #   protocol.stream_conversation(messages) do |msg|
    #     case msg
    #     when ClaudeAgent::AssistantMessage
    #       puts msg.text
    #     when ClaudeAgent::ResultMessage
    #       puts "Done!"
    #     end
    #   end
    #
    def stream_conversation(stream, session_id: "default", &block)
      return enum_for(:stream_conversation, stream, session_id: session_id) unless block_given?

      # Track errors from the sender thread
      sender_error = nil

      # Start sender thread
      sender_thread = Thread.new do
        stream_input(stream, session_id: session_id)
      rescue AbortError => e
        sender_error = e
      rescue => e
        sender_error = e
        # Don't re-raise here; let the main thread handle it
      end

      # Yield responses until we get a ResultMessage or error
      begin
        each_message do |message|
          # Check if sender had an error
          if sender_error
            raise sender_error if sender_error.is_a?(AbortError)

            raise Error, "Stream input error: #{sender_error.message}"
          end

          yield message
          break if message.is_a?(ResultMessage)
        end
      ensure
        # Wait for sender to finish
        sender_thread.join(1)
      end

      # Check for sender errors after loop
      raise sender_error if sender_error.is_a?(AbortError)

      raise Error, "Stream input error: #{sender_error.message}" if sender_error
    end

    # Send an interrupt request
    # @return [void]
    def interrupt
      send_control_request(subtype: "interrupt")
    end

    # Change the permission mode
    # @param mode [String] New permission mode
    # @return [Hash] Response
    def set_permission_mode(mode)
      send_control_request(subtype: "set_permission_mode", mode: mode)
    end

    # Change the model
    # @param model [String, nil] New model name
    # @return [Hash] Response
    def set_model(model)
      send_control_request(subtype: "set_model", model: model)
    end

    # Rewind files to a previous state
    # @param user_message_id [String] UUID of user message to rewind to
    # @param dry_run [Boolean] If true, preview changes without modifying files
    # @return [RewindFilesResult] Result with rewind information
    def rewind_files(user_message_id, dry_run: false)
      request = { user_message_id: user_message_id }
      request[:dry_run] = dry_run if dry_run

      response = send_control_request(subtype: "rewind_files", **request)

      RewindFilesResult.new(
        can_rewind: response["canRewind"] || response["can_rewind"] || false,
        error: response["error"],
        files_changed: response["filesChanged"] || response["files_changed"],
        insertions: response["insertions"],
        deletions: response["deletions"]
      )
    end

    # Set maximum thinking tokens (TypeScript SDK parity)
    # @param tokens [Integer, nil] Max thinking tokens (nil to reset)
    # @return [Hash] Response
    def set_max_thinking_tokens(tokens)
      send_control_request(subtype: "set_max_thinking_tokens", max_thinking_tokens: tokens)
    end

    # Get available slash commands (TypeScript SDK parity)
    # @return [Array<SlashCommand>]
    def supported_commands
      response = send_control_request(subtype: "supported_commands")
      (response["commands"] || []).map do |cmd|
        SlashCommand.new(
          name: cmd["name"],
          description: cmd["description"],
          argument_hint: cmd["argumentHint"]
        )
      end
    end

    # Get full initialization result (TypeScript SDK parity)
    #
    # Sends the supported_commands request and maps the full response including
    # commands, output style, available output styles, models, and account info.
    #
    # @return [InitializationResult]
    def initialization_result
      response = send_control_request(subtype: "supported_commands")

      commands = (response["commands"] || []).map do |cmd|
        SlashCommand.new(
          name: cmd["name"],
          description: cmd["description"],
          argument_hint: cmd["argumentHint"]
        )
      end

      models = (response["models"] || []).map do |model|
        ModelInfo.new(
          value: model["value"],
          display_name: model["displayName"],
          description: model["description"]
        )
      end

      account_data = response["account"]
      account = if account_data
        AccountInfo.new(
          email: account_data["email"],
          organization: account_data["organization"],
          subscription_type: account_data["subscriptionType"],
          token_source: account_data["tokenSource"],
          api_key_source: account_data["apiKeySource"]
        )
      end

      InitializationResult.new(
        commands: commands,
        output_style: response["output_style"],
        available_output_styles: response["available_output_styles"] || [],
        models: models,
        account: account
      )
    end

    # Get available models (TypeScript SDK parity)
    # @return [Array<ModelInfo>]
    def supported_models
      response = send_control_request(subtype: "supported_models")
      (response["models"] || []).map do |model|
        ModelInfo.new(
          value: model["value"],
          display_name: model["displayName"],
          description: model["description"]
        )
      end
    end

    # Get MCP server status (TypeScript SDK parity)
    # @return [Array<McpServerStatus>]
    def mcp_server_status
      response = send_control_request(subtype: "mcp_server_status")
      (response["servers"] || []).map do |server|
        McpServerStatus.new(
          name: server["name"],
          status: server["status"],
          server_info: server["serverInfo"]
        )
      end
    end

    # Get account information (TypeScript SDK parity)
    # @return [AccountInfo]
    def account_info
      response = send_control_request(subtype: "account_info")
      AccountInfo.new(
        email: response["email"],
        organization: response["organization"],
        subscription_type: response["subscriptionType"],
        token_source: response["tokenSource"],
        api_key_source: response["apiKeySource"]
      )
    end

    # Reconnect to an MCP server (TypeScript SDK parity)
    #
    # Attempts to reconnect to a disconnected or errored MCP server.
    #
    # @param server_name [String] Name of the MCP server to reconnect
    # @return [Hash] Response from the CLI
    #
    # @example
    #   protocol.mcp_reconnect("my-server")
    #
    def mcp_reconnect(server_name)
      send_control_request(subtype: "mcp_reconnect", serverName: server_name)
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
    #   protocol.mcp_toggle("my-server", enabled: true)
    #
    # @example Disable a server
    #   protocol.mcp_toggle("my-server", enabled: false)
    #
    def mcp_toggle(server_name, enabled:)
      send_control_request(subtype: "mcp_toggle", serverName: server_name, enabled: enabled)
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
    #   protocol.stop_task("task-123")
    #
    def stop_task(task_id)
      send_control_request(subtype: "stop_task", task_id: task_id)
    end

    # Apply flag settings (TypeScript SDK v0.2.50 parity)
    #
    # Merges the provided settings into the flag settings layer.
    #
    # @param settings [Hash] Settings to merge into the flag layer
    # @return [Hash] Response from the CLI
    #
    # @example
    #   protocol.apply_flag_settings({ "model" => "claude-sonnet-4-5-20250514" })
    #
    def apply_flag_settings(settings)
      send_control_request(subtype: "apply_flag_settings", settings: settings)
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
    #   result = protocol.set_mcp_servers({
    #     "my-server" => { type: "stdio", command: "node", args: ["server.js"] }
    #   })
    #   puts "Added: #{result.added}"
    #   puts "Removed: #{result.removed}"
    #
    def set_mcp_servers(servers)
      # Convert servers hash to format expected by CLI
      servers_config = servers.reject do |_, config|
        config.is_a?(Hash) && (config[:type] == "sdk" || config["type"] == "sdk")
      end

      response = send_control_request(subtype: "mcp_set_servers", servers: servers_config)

      McpSetServersResult.new(
        added: response["added"] || [],
        removed: response["removed"] || [],
        errors: response["errors"] || {}
      )
    end

    private

    def logger
      @options.effective_logger
    end

    # Background thread that reads messages and routes them
    def reader_loop
      @transport.read_messages do |raw|
        # Check abort signal on each iteration
        if @abort_signal&.aborted?
          @running = false
          break
        end

        break unless @running

        if raw["type"] == "control_request"
          logger.debug("protocol") { "Control request received: #{raw.dig("request", "subtype")}" }
          handle_control_request(raw)
        elsif raw["type"] == "control_response"
          logger.debug("protocol") { "Control response received: #{raw.dig("response", "request_id")}" }
          handle_control_response(raw)
        else
          # SDK message - queue for consumer
          logger.debug("protocol") { "Queued message: #{raw["type"]}" }
          @message_queue.push(raw)
        end
      end
    rescue IOError, Errno::EPIPE
      logger.debug("protocol") { "Reader thread exiting: transport closed" }
      @running = false
    rescue AbortError
      logger.debug("protocol") { "Reader thread exiting: abort signal" }
      @running = false
    end

    # Send initialization request
    # @return [Hash] Server info
    def send_initialize
      hooks_config = build_hooks_config

      request = { subtype: "initialize" }
      request[:hooks] = hooks_config if hooks_config
      request[:promptSuggestions] = true if options.prompt_suggestions

      send_control_request(**request)
    end

    # Build hooks configuration for initialization
    # @return [Hash, nil]
    def build_hooks_config
      return nil unless options.has_hooks?

      config = {}

      options.hooks.each do |event, matchers|
        config[event] = matchers.map.with_index do |matcher, idx|
          callback_ids = matcher.callbacks.map.with_index do |callback, cidx|
            callback_id = "hook_#{event}_#{idx}_#{cidx}"
            @hook_callbacks[callback_id] = callback
            callback_id
          end

          entry = {
            matcher: matcher.matcher,
            hookCallbackIds: callback_ids
          }
          entry[:timeout] = matcher.timeout if matcher.timeout
          entry
        end
      end

      config
    end

    # Handle incoming control request from CLI
    # @param raw [Hash] Raw control request
    def handle_control_request(raw)
      request = raw["request"] || {}
      request_id = raw["request_id"]
      subtype = request["subtype"]

      response = case subtype
      when "can_use_tool"
        handle_can_use_tool(request)
      when "hook_callback"
        handle_hook_callback(request)
      when "mcp_message"
        handle_mcp_message(request)
      else
        { error: "Unknown control request subtype: #{subtype}" }
      end

      send_control_response(request_id, response)
    rescue => e
      send_control_response(request_id, { error: e.message })
    end

    # Handle can_use_tool permission request
    # @param request [Hash] Request data
    # @return [Hash] Response
    def handle_can_use_tool(request)
      unless options.can_use_tool
        logger.info("protocol") { "Permission decision for #{request["tool_name"]}: allow (no callback)" }
        return { behavior: "allow" }
      end

      tool_name = request["tool_name"]
      input = (request["input"] || {}).deep_symbolize_keys
      context = {
        permission_suggestions: request["permission_suggestions"],
        blocked_path: request["blocked_path"],
        decision_reason: request["decision_reason"],
        tool_use_id: request["tool_use_id"],
        agent_id: request["agent_id"],
        description: request["description"]
      }

      result = options.can_use_tool.call(tool_name, input, context)

      normalized = result.to_h
      logger.info("protocol") { "Permission decision for #{tool_name}: #{normalized[:behavior]}" }

      if normalized[:behavior] == "allow" && !normalized.key?(:updatedInput)
        normalized[:updatedInput] = input
      end

      normalized
    end

    # Handle hook callback request
    # @param request [Hash] Request data
    # @return [Hash] Response
    def handle_hook_callback(request)
      callback_id = request["callback_id"]
      input = (request["input"] || {}).deep_symbolize_keys
      tool_use_id = request["tool_use_id"]

      callback = @hook_callbacks[callback_id]
      unless callback
        logger.debug("protocol") { "Hook callback not found: #{callback_id}" }
        return {}
      end
      logger.debug("protocol") { "Hook callback: #{callback_id}" }

      context = { tool_use_id: tool_use_id }
      result = callback.call(input, context)

      # Normalize result - convert Ruby field names to CLI field names
      normalize_hook_response(result || {})
    end

    # Handle MCP message routing
    # @param request [Hash] Request data
    # @return [Hash] Response
    def handle_mcp_message(request)
      server_name = request["server_name"]
      message = request["message"]
      logger.debug("protocol") { "MCP message for #{server_name}: #{message["method"]}" }

      # Find SDK MCP server
      server_config = options.mcp_servers[server_name]
      return { error: "Unknown MCP server: #{server_name}" } unless server_config
      return { error: "Not an SDK MCP server" } unless server_config[:type] == "sdk"

      server_instance = server_config[:instance]
      return { error: "No server instance" } unless server_instance

      # Route message to server
      mcp_response = server_instance.handle_message(message)
      { mcp_response: mcp_response }
    end

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

    # Normalize hook response for CLI
    # @param result [Hash] Raw result from callback
    # @return [Hash] Normalized response
    def normalize_hook_response(result)
      result = result.to_h

      response = HOOK_RESPONSE_KEYS.each_with_object({}) do |(ruby_key, json_key), acc|
        acc[json_key] = result[ruby_key] if result.key?(ruby_key)
      end

      if result[:hook_specific_output]
        response["hookSpecificOutput"] = normalize_hook_specific_output(result[:hook_specific_output])
      end

      response
    end

    # Normalize hookSpecificOutput nested fields to camelCase
    # @param hso [Hash] Hook-specific output
    # @return [Hash] Normalized output
    def normalize_hook_specific_output(hso)
      hso.each_with_object({}) do |(key, value), normalized|
        camel_key = key.to_s.camelize(:lower)
        normalized[camel_key] = value
      end
    end

    # Handle control response from CLI
    # @param raw [Hash] Raw control response
    def handle_control_response(raw)
      response = raw["response"] || {}
      request_id = response["request_id"]

      @mutex.synchronize do
        if @pending_requests.key?(request_id)
          @pending_results[request_id] = response
          @condition.broadcast
        end
      end
    end

    # Send a control request and wait for response
    # @param subtype [String] Request subtype
    # @param kwargs [Hash] Additional request data
    # @param timeout [Integer] Timeout in seconds
    # @return [Hash] Response data
    # @raise [AbortError] If abort signal is triggered
    def send_control_request(subtype:, timeout: DEFAULT_TIMEOUT, **kwargs)
      # Check abort signal before sending
      @abort_signal&.check!

      request_id = generate_request_id
      logger.debug("protocol") { "Sending control request: #{subtype} (#{request_id})" }

      request = {
        type: "control_request",
        request_id: request_id,
        request: { subtype: subtype, **kwargs }
      }

      @mutex.synchronize do
        @pending_requests[request_id] = true
      end

      write_message(request)

      # Wait for response
      response = nil
      @mutex.synchronize do
        deadline = Time.now + timeout
        until @pending_results.key?(request_id)
          # Check abort signal during wait (outside mutex for thread safety)
          if @abort_signal&.aborted?
            @pending_requests.delete(request_id)
            raise AbortError, @abort_signal.reason
          end

          remaining = deadline - Time.now
          if remaining <= 0
            @pending_requests.delete(request_id)
            raise TimeoutError.new("Control request timed out", request_id: request_id, timeout_seconds: timeout)
          end
          @condition.wait(@mutex, [ remaining, 0.1 ].min) # Wake up periodically to check abort
        end
        response = @pending_results.delete(request_id)
        @pending_requests.delete(request_id)
      end

      if response["subtype"] == "error"
        logger.error("protocol") { "Control request failed: #{subtype} - #{response["error"]}" }
        raise Error, response["error"] || "Unknown error"
      end

      response["response"] || response
    end

    # Send a control response
    # @param request_id [String] Request ID to respond to
    # @param data [Hash] Response data
    def send_control_response(request_id, data)
      response = {
        type: "control_response",
        response: {
          subtype: data[:error] ? "error" : "success",
          request_id: request_id
        }
      }

      if data[:error]
        response[:response][:error] = data[:error]
      else
        response[:response][:response] = data
      end

      write_message(response)
    end

    # Write a message to the transport
    # @param message [Hash] Message to write
    def write_message(message)
      json = JSON.generate(message)
      @transport.write(json)
    end

    # Generate a unique request ID
    # @return [String]
    def generate_request_id
      @mutex.synchronize do
        @request_counter += 1
        "#{REQUEST_ID_PREFIX}_#{@request_counter}_#{SecureRandom.hex(4)}"
      end
    end
  end
end
