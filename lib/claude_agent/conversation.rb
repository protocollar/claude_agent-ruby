# frozen_string_literal: true

module ClaudeAgent
  # High-level conversation interface managing the full lifecycle.
  #
  # Wraps {Client} and composes {TurnResult}, {EventHandler},
  # {CumulativeUsage}, and {PermissionQueue} into a single stateful
  # object. Auto-connects on first {#say}, tracks multi-turn history,
  # and builds a unified tool activity timeline.
  #
  # @example Basic
  #   conversation = ClaudeAgent::Conversation.new(
  #     model: "claude-sonnet-4-5-20250514",
  #     on_stream: ->(text) { print text }
  #   )
  #   turn = conversation.say("Fix the bug in auth.rb")
  #   puts turn.text
  #   conversation.close
  #
  # @example Block form
  #   ClaudeAgent::Conversation.open(permission_mode: "default") do |c|
  #     c.say("Help me write a function")
  #     c.say("Now add tests")
  #     puts "Total cost: $#{c.total_cost}"
  #   end
  #
  # @example Resume a previous session
  #   conversation = ClaudeAgent::Conversation.resume("session-abc")
  #   conversation.say("Continue where we left off")
  #
  class Conversation
    # Keys consumed by Conversation; everything else forwards to Options
    CONVERSATION_KEYS = %i[
      on_text on_stream on_tool_use on_tool_result
      on_thinking on_result on_message on_permission
      client options
    ].freeze

    attr_reader :turns, :messages, :tool_activity, :client

    # Open a conversation with automatic cleanup.
    #
    # @yield [Conversation] The conversation
    # @return [Object] Result of block
    def self.open(**kwargs)
      conversation = new(**kwargs)
      begin
        yield conversation
      ensure
        conversation.close
      end
    end

    # Resume a previous conversation by session ID.
    #
    # @param session_id [String] Session ID to resume
    # @return [Conversation]
    def self.resume(session_id, **kwargs)
      new(resume: session_id, **kwargs)
    end

    # Create a new conversation.
    #
    # Accepts all {Options} keyword arguments plus conversation-level
    # callbacks:
    #
    # @param on_text [Proc] Handler for streaming text
    # @param on_stream [Proc] Alias for on_text
    # @param on_tool_use [Proc] Handler for tool use events
    # @param on_tool_result [Proc] Handler for tool result events
    # @param on_thinking [Proc] Handler for thinking events
    # @param on_result [Proc] Handler for result events
    # @param on_message [Proc] Handler for all messages
    # @param on_permission [Symbol, Proc] :queue (default) or a callable for can_use_tool
    # @param client [Client] Pre-built client (for testing)
    # @param options [Options] Pre-built options object
    #
    def initialize(**kwargs)
      conversation_kwargs = kwargs.slice(*CONVERSATION_KEYS)
      options_kwargs = kwargs.except(*CONVERSATION_KEYS)

      @options = conversation_kwargs[:options] || build_options(options_kwargs, conversation_kwargs)
      @client = conversation_kwargs[:client] || Client.new(options: @options)

      @turns = []
      @messages = []
      @tool_activity = []
      @tool_use_timestamps = {}
      @tool_result_timestamps = {}
      @connected = false
      @closed = false

      register_callbacks(conversation_kwargs)
      register_timing_hooks
    end

    # Send a message and receive the complete turn result.
    #
    # Auto-connects on first call. Appends to conversation history.
    #
    # @param prompt [String, Array] The message content
    # @yield [Message] Each message as it streams in (optional)
    # @return [TurnResult] The completed turn
    def say(prompt, &block)
      ensure_connected!

      logger.debug("conversation") { "Turn #{@turns.size}: sending message" }

      turn = @client.send_and_receive(prompt) do |message|
        @messages << message
        block&.call(message)
      end

      @turns << turn
      build_tool_activities(turn, @turns.size - 1)

      logger.info("conversation") { "Turn #{@turns.size - 1} complete (#{turn.tool_uses.size} tools, cost=$#{total_cost})" }

      turn
    end

    # Total cost across all turns.
    # @return [Float]
    def total_cost
      @client.cumulative_usage.total_cost_usd
    end

    # Session ID from the most recent turn.
    # @return [String, nil]
    def session_id
      @turns.last&.session_id
    end

    # Cumulative usage stats.
    # @return [CumulativeUsage]
    def usage
      @client.cumulative_usage
    end

    # Non-blocking poll for the next pending permission request.
    # @return [PermissionRequest, nil]
    def pending_permission
      @client.pending_permission
    end

    # Whether any permission requests are pending.
    # @return [Boolean]
    def pending_permissions?
      @client.pending_permissions?
    end

    # Close the conversation and disconnect the client.
    # @return [void]
    def close
      return if @closed
      logger.info("conversation") { "Closing (#{@turns.size} turns, cost=$#{total_cost})" }
      @client.disconnect if @connected
      @connected = false
      @closed = true
    end

    # Whether the conversation is open (client connected).
    # @return [Boolean]
    def open?
      @connected && !@closed
    end

    # Whether the conversation has been closed.
    # @return [Boolean]
    def closed?
      @closed
    end

    def inspect
      parts = [ "#<#{self.class}" ]
      parts << "turns=#{@turns.size}"
      parts << "messages=#{@messages.size}"
      parts << "tools=#{@tool_activity.size}" unless @tool_activity.empty?
      parts << "cost=$#{total_cost}" if total_cost > 0
      parts << "session=#{session_id}" if session_id
      parts << (
        if closed?
          "closed"
        else
          open? ? "open" : "pending"
        end)
      "#{parts.join(" ")}>"
    end

    private

    def build_options(options_kwargs, conversation_kwargs)
      permission = conversation_kwargs[:on_permission]

      if permission.respond_to?(:call)
        options_kwargs[:can_use_tool] = permission
      elsif permission == :queue || permission.nil?
        options_kwargs[:permission_queue] = true unless options_kwargs.key?(:can_use_tool)
      end

      Options.new(**options_kwargs)
    end

    def register_callbacks(kwargs)
      mapping = {
        on_text: :text, on_stream: :text, on_thinking: :thinking,
        on_tool_use: :tool_use, on_tool_result: :tool_result,
        on_result: :result, on_message: :message
      }

      mapping.each do |key, event|
        callback = kwargs[key]
        @client.on(event, &callback) if callback
      end
    end

    def register_timing_hooks
      @client.on(:tool_use) { |tool| @tool_use_timestamps[tool.id] = Time.now }
      @client.on(:tool_result) { |result, _| @tool_result_timestamps[result.tool_use_id] = Time.now }
    end

    def build_tool_activities(turn, turn_index)
      turn.tool_executions.each do |exec|
        tool_id = exec[:tool_use].id
        @tool_activity << ToolActivity.new(
          tool_use: exec[:tool_use],
          tool_result: exec[:tool_result],
          turn_index: turn_index,
          started_at: @tool_use_timestamps.delete(tool_id),
          completed_at: @tool_result_timestamps.delete(tool_id)
        )
      end
    end

    def logger
      @options.effective_logger
    end

    def ensure_connected!
      raise Error, "Conversation is closed" if @closed
      return if @connected

      logger.info("conversation") { "Auto-connecting" }
      @client.connect
      @connected = true
    end
  end
end
