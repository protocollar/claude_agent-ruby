# frozen_string_literal: true

module ClaudeAgent
  # V2 Session options (subset of full Options)
  # V2 API - UNSTABLE
  # @alpha
  #
  # @example
  #   options = SessionOptions.new(
  #     model: "claude-sonnet-4-5-20250929",
  #     permission_mode: "acceptEdits"
  #   )
  #
  SessionOptions = Data.define(
    :model,
    :path_to_claude_code_executable,
    :env,
    :allowed_tools,
    :disallowed_tools,
    :can_use_tool,
    :hooks,
    :permission_mode
  ) do
    def initialize(
      model:,
      path_to_claude_code_executable: nil,
      env: nil,
      allowed_tools: nil,
      disallowed_tools: nil,
      can_use_tool: nil,
      hooks: nil,
      permission_mode: nil
    )
      super
    end
  end

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
  class Session
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

  class << self
    # V2 API - UNSTABLE
    # Create a persistent session for multi-turn conversations.
    #
    # @param options [Hash, SessionOptions] Session configuration
    # @return [Session] A new session instance
    # @alpha
    #
    # @example
    #   session = ClaudeAgent.unstable_v2_create_session(model: "claude-sonnet-4-5-20250929")
    #
    def unstable_v2_create_session(options)
      Session.new(options)
    end

    # V2 API - UNSTABLE
    # Resume an existing session by ID.
    #
    # @param session_id [String] The session ID to resume
    # @param options [Hash, SessionOptions] Session configuration
    # @return [Session] A session configured to resume the specified session
    # @alpha
    #
    # @example
    #   session = ClaudeAgent.unstable_v2_resume_session("session-abc123", model: "claude-sonnet-4-5-20250929")
    #
    def unstable_v2_resume_session(session_id, options)
      # For resumption, we need to pass the resume option through
      # Since SessionOptions doesn't have resume, we handle it in the Client options
      session = Session.new(options)
      session.instance_variable_set(:@resume_session_id, session_id)

      # Override build_client_options to include resume
      session.define_singleton_method(:build_client_options) do
        Options.new(
          model: @options.model,
          cli_path: @options.path_to_claude_code_executable,
          env: @options.env,
          allowed_tools: @options.allowed_tools,
          disallowed_tools: @options.disallowed_tools,
          can_use_tool: @options.can_use_tool,
          hooks: @options.hooks,
          permission_mode: @options.permission_mode,
          resume: @resume_session_id
        )
      end

      session
    end

    # V2 API - UNSTABLE
    # One-shot convenience function for single prompts.
    #
    # @param message [String] The prompt message
    # @param options [Hash, SessionOptions] Session configuration
    # @return [ResultMessage] The result of the query
    # @alpha
    #
    # @example
    #   result = ClaudeAgent.unstable_v2_prompt("What files are here?", model: "claude-sonnet-4-5-20250929")
    #
    def unstable_v2_prompt(message, options)
      session = unstable_v2_create_session(options)
      begin
        session.send(message)
        result = nil
        session.stream.each do |msg|
          result = msg if msg.is_a?(ResultMessage)
        end
        result
      ensure
        session.close
      end
    end
  end
end
