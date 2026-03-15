# frozen_string_literal: true

module ClaudeAgent
  class ControlProtocol
    # Connection lifecycle: start, stop, abort, and the background reader loop.
    module Lifecycle
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

        # Drain permission queue so reader thread unblocks
        @permission_queue&.drain!(reason: "Operation aborted")

        # Send cancel requests for pending operations (protocol courtesy)
        @mutex.synchronize do
          @pending_requests.each_key do |request_id|
            begin
              write_message({ type: "control_cancel_request", request_id: request_id })
            rescue
              # Ignore transport errors during abort — fire-and-forget
            end
          end
        end

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

        # Unblock the consumer and terminate the transport
        @message_queue.push(:done)
        @transport.terminate if @transport.respond_to?(:terminate)
      end

      private

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
      ensure
        @message_queue.push(:done)
      end
    end
  end
end
