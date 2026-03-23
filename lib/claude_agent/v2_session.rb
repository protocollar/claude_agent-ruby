# frozen_string_literal: true

module ClaudeAgent
  # V2 API - UNSTABLE
  # Multi-turn session interface for persistent conversations.
  #
  # This provides a simpler interface than the full Client class,
  # matching the TypeScript SDK's SDKSession interface.
  #
  # @alpha
  #
  # @example Create a session and send messages
  #   session = ClaudeAgent.unstable_v2_create_session(model: "claude-sonnet-4-5-20250929")
  #   session.send("Hello!")
  #   session.stream.each { |msg| puts msg.inspect }
  #   session.close
  #
  class V2Session
    attr_reader :session_id, :options

    def initialize(options)
      @options = options.is_a?(SessionOptions) ? options : SessionOptions.new(**options)
      @client = nil
      @session_id = nil
      @closed = false
    end

    # Send a message to the agent
    #
    # @param message [String, UserMessage] The message to send
    # @return [void]
    def send(message)
      ensure_connected!
      content = message.is_a?(String) ? message : message
      @client.send_message(content)
    end

    # Stream messages from the agent
    #
    # @return [Enumerator<message>] An enumerator of messages
    # @yield [message] Each message received from the agent
    def stream(&block)
      ensure_connected!
      if block_given?
        @client.receive_response(&block)
      else
        @client.receive_response
      end
    end

    # Close the session
    #
    # @return [void]
    def close
      return if @closed
      @client&.disconnect
      @closed = true
    end

    # Check if session is closed
    #
    # @return [Boolean]
    def closed?
      @closed
    end

    private

    def ensure_connected!
      raise AbortError, "Session is closed" if @closed
      return if @client&.connected?

      @client = Client.new(options: build_client_options)
      @client.connect
      update_session_id
    end

    def build_client_options
      Options.new(
        model: @options.model,
        cli_path: @options.path_to_claude_code_executable,
        env: @options.env,
        allowed_tools: @options.allowed_tools,
        disallowed_tools: @options.disallowed_tools,
        can_use_tool: @options.can_use_tool,
        hooks: @options.hooks,
        permission_mode: @options.permission_mode
      )
    end

    def update_session_id
      # Session ID is typically extracted from the first system message
      # but since we don't have it immediately, we leave it nil until available
      @session_id = @client.server_info&.dig("session_id")
    end
  end
end
