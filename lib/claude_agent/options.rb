# frozen_string_literal: true

require_relative "options/serializer"

module ClaudeAgent
  # Permission modes for tool execution (TypeScript SDK parity)
  PERMISSION_MODES = %w[default acceptEdits plan bypassPermissions dontAsk].freeze

  # Configuration options for ClaudeAgent queries and clients
  #
  # @example Basic usage
  #   options = ClaudeAgent::Options.new(
  #     model: "claude-sonnet-4-5-20250514",
  #     max_turns: 10
  #   )
  #
  # @example With tools and permissions
  #   options = ClaudeAgent::Options.new(
  #     tools: ["Read", "Write", "Bash"],
  #     permission_mode: "acceptEdits",
  #     can_use_tool: ->(name, input, context) { { behavior: "allow" } }
  #   )
  #
  class Options
    include Serializer

    # Default values for options that have non-nil defaults
    DEFAULTS = {
      allowed_tools: [],
      disallowed_tools: [],
      allow_dangerously_skip_permissions: false,
      continue_conversation: false,
      fork_session: false,
      strict_mcp_config: false,
      mcp_servers: {},
      add_dirs: [],
      env: {},
      extra_args: {},
      plugins: [],
      include_partial_messages: false,
      enable_file_checkpointing: false,
      persist_session: true,
      betas: [],
      prompt_suggestions: false,
      debug: false,
      debug_file: nil
    }.freeze

    # All configurable attributes
    # Valid effort levels for the effort option
    EFFORT_LEVELS = %w[low medium high max].freeze

    ATTRIBUTES = %i[
      tools allowed_tools disallowed_tools
      system_prompt append_system_prompt
      model fallback_model
      permission_mode permission_prompt_tool_name can_use_tool on_elicitation allow_dangerously_skip_permissions
      permission_queue
      continue_conversation resume fork_session resume_session_at session_id
      max_turns max_budget_usd thinking effort max_thinking_tokens
      strict_mcp_config mcp_servers hooks
      sandbox cwd add_dirs env agent
      cli_path extra_args agents setting_sources settings plugins
      include_partial_messages output_format enable_file_checkpointing
      persist_session prompt_suggestions betas max_buffer_size stderr_callback
      abort_controller spawn_claude_code_process
      debug debug_file
      tool_config
      agent_progress_summaries
      logger
    ].freeze

    attr_accessor(*ATTRIBUTES)

    def initialize(**kwargs)
      # Remove nil values so they don't override defaults
      filtered = kwargs.compact
      merged = DEFAULTS.merge(filtered)
      ATTRIBUTES.each do |attr|
        instance_variable_set(:"@#{attr}", merged[attr])
      end
      validate!
    end

    # Check if SDK MCP servers are configured
    # @return [Boolean]
    def has_sdk_mcp_servers?
      return false unless mcp_servers.is_a?(Hash)

      mcp_servers.any? { |_, v| v.is_a?(Hash) && v[:type] == "sdk" }
    end

    # Check if hooks are configured
    # @return [Boolean]
    def has_hooks?
      hooks&.any? || false
    end

    # Get the abort signal from the controller
    # @return [AbortSignal, nil]
    def abort_signal
      abort_controller&.signal
    end

    # Resolved logger: per-instance override or module-level default
    # @return [Logger]
    def effective_logger
      @logger || ClaudeAgent.logger
    end

    private

    # --- Validation ---

    def validate!
      if permission_mode && !PERMISSION_MODES.include?(permission_mode)
        raise ConfigurationError, "Invalid permission_mode: #{permission_mode}. Must be one of: #{PERMISSION_MODES.join(", ")}"
      end

      if permission_mode == "bypassPermissions" && !allow_dangerously_skip_permissions
        raise ConfigurationError,
              "Must set allow_dangerously_skip_permissions: true to use bypassPermissions mode"
      end

      # Auto-compile PermissionPolicy to can_use_tool lambda
      if can_use_tool.is_a?(PermissionPolicy)
        @can_use_tool = can_use_tool.to_can_use_tool
      end

      if can_use_tool && !can_use_tool.respond_to?(:call)
        raise ConfigurationError, "can_use_tool must be callable (Proc, Lambda, or object responding to #call)"
      end

      # Normalize hooks to HookRegistry
      @hooks = HookRegistry.wrap(hooks) if hooks && !hooks.is_a?(HookRegistry)

      if on_elicitation && !on_elicitation.respond_to?(:call)
        raise ConfigurationError, "on_elicitation must be callable (Proc, Lambda, or object responding to #call)"
      end

      # Auto-set permission_prompt_tool_name to "stdio" when can_use_tool or
      # permission_queue is configured, so the CLI routes permission prompts
      # through the control protocol instead of interactive terminal prompts
      if (can_use_tool || permission_queue) && !permission_prompt_tool_name
        @permission_prompt_tool_name = "stdio"
      end

      if max_turns && (!max_turns.is_a?(Integer) || max_turns < 1)
        raise ConfigurationError, "max_turns must be a positive integer"
      end

      if max_budget_usd && (!max_budget_usd.is_a?(Numeric) || max_budget_usd <= 0)
        raise ConfigurationError, "max_budget_usd must be a positive number"
      end

      if thinking
        unless thinking.is_a?(Hash)
          raise ConfigurationError, "thinking must be a Hash with :type key (e.g., { type: 'adaptive' })"
        end
        type = thinking[:type] || thinking["type"]
        unless %w[adaptive enabled disabled].include?(type)
          raise ConfigurationError, "thinking[:type] must be one of: adaptive, enabled, disabled"
        end
      end

      if effort && !EFFORT_LEVELS.include?(effort)
        raise ConfigurationError, "Invalid effort: #{effort}. Must be one of: #{EFFORT_LEVELS.join(", ")}"
      end

      if session_id && (continue_conversation || resume) && !fork_session
        raise ConfigurationError, "session_id cannot be used with continue or resume unless fork_session is also set"
      end
    end
  end
end
