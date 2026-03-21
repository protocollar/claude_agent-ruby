# frozen_string_literal: true

module ClaudeAgent
  class ControlProtocol
    # Low-level protocol primitives: sending/receiving control messages,
    # writing to transport, request ID generation, and initialization.
    module Primitives
      private

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

      # Send initialization request
      # @return [Hash] Server info
      def send_initialize
        hooks_config = build_hooks_config

        request = { subtype: "initialize" }
        request[:hooks] = hooks_config if hooks_config
        request[:promptSuggestions] = true if options.prompt_suggestions
        request[:sdkMcpServers] = sdk_mcp_server_names if options.has_sdk_mcp_servers?
        request[:toolConfig] = options.tool_config if options.tool_config
        request[:agentProgressSummaries] = true if options.agent_progress_summaries

        send_control_request(**request)
      end

      # Build hooks configuration for initialization
      # @return [Hash, nil]
      def build_hooks_config
        return nil unless options.has_hooks?

        options.hooks.each_with_object({}) do |(event, hooks), config|
          config[event] = hooks.each_with_index.map do |hook, idx|
            hook.to_config(idx, @hook_callbacks)
          end
        end
      end

      # Extract SDK MCP server names from options
      # @return [Array<String>]
      def sdk_mcp_server_names
        options.mcp_servers
          .select { |_, v| v.is_a?(Hash) && v[:type] == "sdk" }
          .keys
          .map(&:to_s)
      end
    end
  end
end
