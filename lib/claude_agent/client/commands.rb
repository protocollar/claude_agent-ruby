# frozen_string_literal: true

module ClaudeAgent
  class Client
    # CLI command delegations to the ControlProtocol.
    #
    # These methods provide the Client-level interface to control commands:
    # permission/model changes, MCP management, task control, and query methods.
    # Each enforces connection state before delegating to the protocol.
    module Commands
      # Change the permission mode
      #
      # @param mode [String] New permission mode
      # @return [Hash] Response
      def set_permission_mode(mode)
        require_connection!

        @protocol.set_permission_mode(mode)
      end

      # Change the model
      #
      # @param model [String, nil] New model name (nil to use default)
      # @return [Hash] Response
      def set_model(model)
        require_connection!

        @protocol.set_model(model)
      end

      # Rewind files to the state at a specific user message
      #
      # @param user_message_id [String] UUID of the user message to rewind to
      # @param dry_run [Boolean] If true, preview changes without modifying files
      # @return [RewindFilesResult] Result with rewind information
      def rewind_files(user_message_id, dry_run: false)
        require_connection!

        @protocol.rewind_files(user_message_id, dry_run: dry_run)
      end

      # Set maximum thinking tokens (TypeScript SDK parity)
      #
      # @param tokens [Integer, nil] Max thinking tokens (nil to reset)
      # @return [Hash] Response
      def set_max_thinking_tokens(tokens)
        require_connection!

        @protocol.set_max_thinking_tokens(tokens)
      end

      # Get available slash commands (TypeScript SDK parity)
      #
      # @return [Array<SlashCommand>]
      def supported_commands
        require_connection!

        @protocol.supported_commands
      end

      # Get available models (TypeScript SDK parity)
      #
      # @return [Array<ModelInfo>]
      def supported_models
        require_connection!

        @protocol.supported_models
      end

      # Get available agents (TypeScript SDK v0.2.63 parity)
      #
      # @return [Array<AgentInfo>]
      def supported_agents
        require_connection!

        @protocol.supported_agents
      end

      # Get MCP server status (TypeScript SDK parity)
      #
      # @return [Array<McpServerStatus>]
      def mcp_server_status
        require_connection!

        @protocol.mcp_server_status
      end

      # Get account information (TypeScript SDK parity)
      #
      # @return [AccountInfo]
      def account_info
        require_connection!

        @protocol.account_info
      end

      # Get full initialization result (TypeScript SDK parity)
      #
      # @return [InitializationResult]
      def initialization_result
        require_connection!

        @protocol.initialization_result
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
      #   client.stop_task("task-123")
      #
      def stop_task(task_id)
        require_connection!

        @protocol.stop_task(task_id)
      end

      # Apply flag settings (TypeScript SDK v0.2.50 parity)
      #
      # Merges the provided settings into the flag settings layer.
      #
      # @param settings [Hash] Settings to merge into the flag layer
      # @return [Hash] Response from the CLI
      #
      # @example
      #   client.apply_flag_settings({ "model" => "claude-sonnet-4-5-20250514" })
      #
      def apply_flag_settings(settings)
        require_connection!

        @protocol.apply_flag_settings(settings)
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
      #   result = client.set_mcp_servers({
      #     "my-server" => { type: "stdio", command: "node", args: ["server.js"] }
      #   })
      #   puts "Added: #{result.added}"
      #   puts "Removed: #{result.removed}"
      #
      def set_mcp_servers(servers)
        require_connection!

        @protocol.set_mcp_servers(servers)
      end

      # Reconnect to an MCP server (TypeScript SDK parity)
      #
      # Attempts to reconnect to a disconnected or errored MCP server.
      #
      # @param server_name [String] Name of the MCP server to reconnect
      # @return [Hash] Response from the CLI
      #
      # @example
      #   client.mcp_reconnect("my-server")
      #
      def mcp_reconnect(server_name)
        require_connection!

        @protocol.mcp_reconnect(server_name)
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
      #   client.mcp_toggle("my-server", enabled: true)
      #
      # @example Disable a server
      #   client.mcp_toggle("my-server", enabled: false)
      #
      def mcp_toggle(server_name, enabled:)
        require_connection!

        @protocol.mcp_toggle(server_name, enabled: enabled)
      end

      # Initiate OAuth authentication for an MCP server (TypeScript SDK v0.2.52 parity)
      #
      # @param server_name [String] Name of the MCP server to authenticate
      # @return [Hash] Response from the CLI
      #
      # @example
      #   client.mcp_authenticate("my-remote-server")
      #
      def mcp_authenticate(server_name)
        require_connection!

        @protocol.mcp_authenticate(server_name)
      end

      # Clear stored auth credentials for an MCP server (TypeScript SDK v0.2.52 parity)
      #
      # @param server_name [String] Name of the MCP server to clear auth for
      # @return [Hash] Response from the CLI
      #
      # @example
      #   client.mcp_clear_auth("my-remote-server")
      #
      def mcp_clear_auth(server_name)
        require_connection!

        @protocol.mcp_clear_auth(server_name)
      end

      # Cancel a queued async user message (TypeScript SDK v0.2.76 parity)
      #
      # Drops a previously queued user message before it is processed.
      #
      # @param message_uuid [String] UUID of the message to cancel
      # @return [Hash] Response from the CLI
      #
      # @example
      #   client.cancel_async_message("msg-uuid-123")
      #
      def cancel_async_message(message_uuid)
        require_connection!

        @protocol.cancel_async_message(message_uuid)
      end

      # Get effective merged settings (TypeScript SDK v0.2.76 parity)
      #
      # Returns the current effective settings after merging all layers.
      #
      # @return [Hash] Merged settings
      #
      # @example
      #   settings = client.get_settings
      #   puts settings["model"]
      #
      def get_settings
        require_connection!

        @protocol.get_settings
      end
    end
  end
end
