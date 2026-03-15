# frozen_string_literal: true

module ClaudeAgent
  class ControlProtocol
    # User message sending, iteration, and streaming conversation support.
    module Messaging
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

        loop do
          @abort_signal&.check!

          raw = @message_queue.pop  # blocks until data available
          break if raw == :done     # sentinel from reader_loop

          begin
            message = @parser.parse(raw)
            yield message
          rescue AbortError
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
    end
  end
end
