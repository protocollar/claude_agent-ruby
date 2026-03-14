# frozen_string_literal: true

module ClaudeAgent
  class ControlProtocol
    # Handles incoming control requests from the CLI: permission checks,
    # hook callbacks, MCP message routing, and elicitation.
    module RequestHandling
      private

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
        when "elicitation"
          handle_elicitation(request)
        else
          { error: "Unknown control request subtype: #{subtype}" }
        end

        send_control_response(request_id, response)
      rescue => e
        send_control_response(request_id, { error: e.message })
      end

      # Handle can_use_tool permission request
      #
      # Supports three modes:
      # 1. Synchronous callback — can_use_tool is set, returns result directly
      # 2. Queue-based — permission_queue is set, enqueues and waits for resolution
      # 3. Default allow — neither is set
      #
      # In hybrid mode (callback + queue), the callback can call
      # context.request.defer! to enqueue the request instead of
      # returning a synchronous answer.
      #
      # @param request [Hash] Request data
      # @return [Hash] Response
      def handle_can_use_tool(request)
        tool_name = request["tool_name"]
        input = (request["input"] || {}).deep_symbolize_keys

        # Build PermissionRequest for queue/hybrid modes
        perm_request = PermissionRequest.new(
          tool_name: tool_name,
          input: input,
          context: nil, # set below after ToolPermissionContext is built
          request_id: request["tool_use_id"] || SecureRandom.hex(8)
        )

        context = ToolPermissionContext.new(
          permission_suggestions: request["permission_suggestions"],
          blocked_path: request["blocked_path"],
          decision_reason: request["decision_reason"],
          tool_use_id: request["tool_use_id"],
          agent_id: request["agent_id"],
          description: request["description"],
          signal: @abort_signal,
          request: perm_request
        )

        # Back-fill context on the request (circular, but both are needed)
        perm_request.instance_variable_set(:@context, context)

        # Mode 1: Synchronous callback
        if options.can_use_tool
          result = options.can_use_tool.call(tool_name, input, context)

          # Check if the callback deferred to the queue
          if perm_request.deferred?
            return enqueue_and_wait(perm_request, tool_name, input)
          end

          return normalize_permission_result(result, tool_name, input)
        end

        # Mode 2: Queue-based
        if @permission_queue
          return enqueue_and_wait(perm_request, tool_name, input)
        end

        # Mode 3: Default allow
        logger.info("protocol") { "Permission decision for #{tool_name}: allow (no callback)" }
        { behavior: "allow" }
      end

      # Enqueue a permission request and block until resolved
      # @param perm_request [PermissionRequest] The request to enqueue
      # @param tool_name [String] Tool name (for logging)
      # @param input [Hash] Original tool input
      # @return [Hash] Normalized response
      def enqueue_and_wait(perm_request, tool_name, input)
        logger.info("protocol") { "Permission request queued for #{tool_name}" }
        @permission_queue.push(perm_request)

        result = perm_request.wait(timeout: DEFAULT_TIMEOUT)
        normalize_permission_result(result, tool_name, input)
      end

      # Normalize a permission result for the CLI response
      # @param result [PermissionResultAllow, PermissionResultDeny, Hash] The result
      # @param tool_name [String] Tool name (for logging)
      # @param input [Hash] Original tool input
      # @return [Hash] Normalized response
      def normalize_permission_result(result, tool_name, input)
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

      # Handle elicitation request from CLI (TypeScript SDK v0.2.63 parity)
      # @param request [Hash] Request data
      # @return [Hash] Response
      def handle_elicitation(request)
        elicitation_request = {
          server_name: request["mcp_server_name"],
          message: request["message"],
          mode: request["mode"],
          url: request["url"],
          elicitation_id: request["elicitation_id"],
          requested_schema: request["requested_schema"]
        }

        if options.on_elicitation
          result = options.on_elicitation.call(elicitation_request, signal: @abort_signal)
          return normalize_elicitation_result(result)
        end

        # Default: decline
        { action: "decline" }
      end

      # Normalize an elicitation result for the CLI response
      # @param result [Hash, nil] The result from the callback
      # @return [Hash] Normalized response
      def normalize_elicitation_result(result)
        return { action: "decline" } unless result

        result = result.to_h if result.respond_to?(:to_h) && !result.is_a?(Hash)
        {
          action: result[:action] || result["action"] || "decline",
          content: result[:content] || result["content"]
        }.compact
      end

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
    end
  end
end
