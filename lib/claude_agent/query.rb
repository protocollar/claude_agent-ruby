# frozen_string_literal: true

module ClaudeAgent
  class << self
    # Run Setup hooks and exit
    #
    # This is a convenience method for running Setup hooks without starting
    # a conversation. Useful for CI/CD pipelines or scripts that need to
    # ensure setup is complete before proceeding.
    #
    # @param trigger [Symbol] The setup trigger (:init or :maintenance)
    # @param options [Options, nil] Additional configuration options
    # @return [Array<Message>] All messages received during setup
    #
    # @example Run init setup
    #   messages = ClaudeAgent.run_setup
    #   result = messages.last
    #   puts "Setup completed" if result.success?
    #
    # @example Run init setup with custom options
    #   options = ClaudeAgent::Options.new(cwd: "/my/project")
    #   ClaudeAgent.run_setup(trigger: :init, options: options)
    #
    # @note The :maintenance trigger requires --maintenance flag which
    #   continues into a conversation. For maintenance-only behavior,
    #   use options with maintenance: true and handle accordingly.
    #
    def run_setup(trigger: :init, options: nil)
      options ||= Options.new

      case trigger
      when :init
        # Create new options with init_only set
        setup_options = Options.new(**options_to_hash(options).merge(init_only: true))
      when :maintenance
        # Note: There's no --maintenance-only flag, so we use --maintenance
        # which will continue into a conversation. The caller should handle this.
        setup_options = Options.new(**options_to_hash(options).merge(maintenance: true))
      else
        raise ArgumentError, "Invalid trigger: #{trigger}. Must be :init or :maintenance"
      end

      # Run with an empty prompt - setup hooks run before the prompt is processed
      query(prompt: "", options: setup_options).to_a
    end

    # One-shot query to Claude Code CLI
    #
    # This is a simple, stateless interface for sending a single prompt
    # and receiving all responses. For interactive conversations, use
    # {ClaudeAgent::Client} instead.
    #
    # @param prompt [String] The prompt to send to Claude
    # @param options [Options, nil] Configuration options
    # @param transport [Transport::Base, nil] Custom transport (default: Subprocess)
    # @return [Enumerator<Message>] Enumerator yielding Message objects
    #
    # @example Basic usage
    #   ClaudeAgent.query(prompt: "What is 2+2?").each do |message|
    #     case message
    #     when ClaudeAgent::AssistantMessage
    #       puts message.text
    #     when ClaudeAgent::ResultMessage
    #       puts "Cost: $#{message.total_cost_usd}"
    #     end
    #   end
    #
    # @example Collect all messages
    #   messages = ClaudeAgent.query(prompt: "Hello").to_a
    #   result = messages.last
    #   puts "Completed in #{result.duration_ms}ms"
    #
    # @example With custom options
    #   options = ClaudeAgent::Options.new(
    #     model: "claude-sonnet-4-5-20250514",
    #     max_turns: 5,
    #     permission_mode: "acceptEdits"
    #   )
    #   ClaudeAgent.query(prompt: "Fix the bug", options: options).each { |m| puts m }
    #
    def query(prompt:, options: nil, transport: nil)
      options ||= Options.new
      transport ||= Transport::Subprocess.new(options: options)

      Enumerator.new do |yielder|
        # Set entrypoint environment variable
        ENV["CLAUDE_CODE_ENTRYPOINT"] = "sdk-rb"
        query_logger = options.effective_logger
        query_logger.info("query") { "Starting query" }
        query_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        # Always use streaming mode with control protocol (Python/TypeScript SDK parity)
        protocol = ControlProtocol.new(transport: transport, options: options)
        begin
          # Register abort handler if abort controller is provided
          if options.abort_signal
            options.abort_signal.on_abort do
              protocol.abort! rescue nil
            end
          end

          protocol.start(streaming: true)
          protocol.send_user_message(prompt)

          protocol.each_message do |message|
            query_logger.debug("query") { "Received: #{message.class.name.split("::").last}" }
            yielder << message

            if message.is_a?(ResultMessage)
              elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - query_start
              query_logger.info("query") { "Query complete (#{elapsed.round(2)}s, cost=$#{message.total_cost_usd || "?"})" }
              break
            end
          end
        ensure
          protocol.stop
        end
      end
    end

    # One-shot query that returns a TurnResult
    #
    # Like {query}, but accumulates all messages into a {TurnResult}
    # for convenient access to text, tool use, usage, and more.
    #
    # @param prompt [String] The prompt to send to Claude
    # @param options [Options, nil] Configuration options
    # @param transport [Transport::Base, nil] Custom transport
    # @yield [Message] Each message as it arrives (optional)
    # @return [TurnResult] The completed turn
    #
    # @example Simple
    #   turn = ClaudeAgent.query_turn(prompt: "What is 2+2?")
    #   puts turn.text
    #   puts "Cost: $#{turn.cost}"
    #
    # @example With streaming
    #   turn = ClaudeAgent.query_turn(prompt: "Explain Ruby") do |msg|
    #     print msg.text if msg.is_a?(ClaudeAgent::AssistantMessage)
    #   end
    #
    def query_turn(prompt:, options: nil, transport: nil)
      turn = TurnResult.new
      query(prompt: prompt, options: options, transport: transport).each do |message|
        turn << message
        yield message if block_given?
      end
      turn
    end

    private

    # Convert an Options object to a hash for merging
    # @param options [Options] The options object
    # @return [Hash] Hash of option values
    def options_to_hash(options)
      Options::ATTRIBUTES.each_with_object({}) do |attr, hash|
        value = options.send(attr)
        hash[attr] = value unless value.nil?
      end
    end
  end
end
