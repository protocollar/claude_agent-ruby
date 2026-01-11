# frozen_string_literal: true

module ClaudeAgent
  class << self
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

        # Determine mode based on hooks/MCP servers
        streaming = options.has_hooks? || options.has_sdk_mcp_servers?

        if streaming
          # Use streaming mode with control protocol
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
            transport.end_input unless options.has_hooks? || options.has_sdk_mcp_servers?

            protocol.each_message do |message|
              yielder << message
              break if message.is_a?(ResultMessage)
            end
          ensure
            protocol.stop
          end
        else
          # Simple mode - just send prompt and read responses
          parser = MessageParser.new
          begin
            transport.connect(streaming: false, prompt: prompt)

            transport.read_messages do |raw|
              message = parser.parse(raw)
              yielder << message
              break if message.is_a?(ResultMessage)
            end
          ensure
            transport.close
          end
        end
      end
    end
  end
end
