# frozen_string_literal: true

module ClaudeAgent
  class ControlProtocol
    # Public control commands: interrupt, model/permission changes,
    # MCP management, task control, and query methods.
    module Commands
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
            description: model["description"],
            supports_effort: model["supportsEffort"],
            supported_effort_levels: model["supportedEffortLevels"],
            supports_adaptive_thinking: model["supportsAdaptiveThinking"],
            supports_fast_mode: model["supportsFastMode"],
            supports_auto_mode: model["supportsAutoMode"]
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

        agents = (response["agents"] || []).map do |agent|
          AgentInfo.new(
            name: agent["name"],
            description: agent["description"],
            model: agent["model"]
          )
        end

        InitializationResult.new(
          commands: commands,
          output_style: response["output_style"],
          available_output_styles: response["available_output_styles"] || [],
          models: models,
          account: account,
          agents: agents,
          fast_mode_state: response["fast_mode_state"]
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
            description: model["description"],
            supports_effort: model["supportsEffort"],
            supported_effort_levels: model["supportedEffortLevels"],
            supports_adaptive_thinking: model["supportsAdaptiveThinking"],
            supports_fast_mode: model["supportsFastMode"],
            supports_auto_mode: model["supportsAutoMode"]
          )
        end
      end

      # Get available agents (TypeScript SDK v0.2.63 parity)
      # @return [Array<AgentInfo>]
      def supported_agents
        response = send_control_request(subtype: "supported_agents")
        (response["agents"] || []).map do |agent|
          AgentInfo.new(
            name: agent["name"],
            description: agent["description"],
            model: agent["model"]
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
            server_info: server["serverInfo"],
            error: server["error"],
            config: server["config"],
            scope: server["scope"],
            tools: server["tools"]
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

      # Initiate OAuth authentication for an MCP server (TypeScript SDK v0.2.52 parity)
      #
      # @param server_name [String] Name of the MCP server to authenticate
      # @return [Hash] Response from the CLI
      #
      # @example
      #   protocol.mcp_authenticate("my-remote-server")
      #
      def mcp_authenticate(server_name)
        send_control_request(subtype: "mcp_authenticate", serverName: server_name)
      end

      # Clear stored auth credentials for an MCP server (TypeScript SDK v0.2.52 parity)
      #
      # @param server_name [String] Name of the MCP server to clear auth for
      # @return [Hash] Response from the CLI
      #
      # @example
      #   protocol.mcp_clear_auth("my-remote-server")
      #
      def mcp_clear_auth(server_name)
        send_control_request(subtype: "mcp_clear_auth", serverName: server_name)
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
      # Cancel a queued async user message (TypeScript SDK v0.2.76 parity)
      #
      # Drops a previously queued user message before it is processed.
      #
      # @param message_uuid [String] UUID of the message to cancel
      # @return [Hash] Response from the CLI
      #
      # @example
      #   protocol.cancel_async_message("msg-uuid-123")
      #
      def cancel_async_message(message_uuid)
        send_control_request(subtype: "cancel_async_message", message_uuid: message_uuid)
      end

      # Get effective merged settings (TypeScript SDK v0.2.76 parity)
      #
      # Returns the current effective settings after merging all layers
      # (user, project, local, flag, etc.).
      #
      # @return [Hash] Merged settings
      #
      # @example
      #   settings = protocol.get_settings
      #   puts settings["model"]
      #
      def get_settings
        send_control_request(subtype: "get_settings")
      end
    end
  end
end
