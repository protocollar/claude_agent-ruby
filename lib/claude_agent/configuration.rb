# frozen_string_literal: true

module ClaudeAgent
  # Global configuration object (Stripe-style).
  #
  # Holds default values for all configurable Options fields. When a
  # query, conversation, or ask/chat call is made without explicit
  # Options, these defaults are merged with per-request overrides to
  # produce the final Options instance.
  #
  # @example Module-level setters
  #   ClaudeAgent.model = "claude-sonnet-4-5-20250514"
  #   ClaudeAgent.permission_mode = "acceptEdits"
  #   ClaudeAgent.max_turns = 10
  #
  # @example Block-based bulk config
  #   ClaudeAgent.configure do |c|
  #     c.model = "claude-sonnet-4-5-20250514"
  #     c.permission_mode = "acceptEdits"
  #     c.max_turns = 10
  #   end
  #
  # @example Per-request overrides (via ask)
  #   ClaudeAgent.ask("Fix the bug", model: "opus", max_turns: 5)
  #
  class Configuration
    # Tier 1: Module-level delegators (set once at boot)
    TIER1_FIELDS = %i[
      model permission_mode max_turns max_budget_usd
      system_prompt append_system_prompt cli_path cwd
      sandbox debug effort persist_session fallback_model
    ].freeze

    # Tier 2: Per-request overrides (common kwargs on ask/chat)
    TIER2_FIELDS = %i[
      tools allowed_tools disallowed_tools thinking output_format
    ].freeze

    # Tier 3: Advanced (accessible via config.xxx= or raw Options.new)
    TIER3_FIELDS = %i[
      mcp_servers hooks env extra_args agents setting_sources settings
      plugins betas spawn_claude_code_process agent add_dirs
      max_buffer_size stderr_callback include_partial_messages
      enable_file_checkpointing prompt_suggestions strict_mcp_config
      tool_config agent_progress_summaries max_thinking_tokens
      debug_file
    ].freeze

    # All configurable fields
    ALL_FIELDS = (TIER1_FIELDS + TIER2_FIELDS + TIER3_FIELDS).freeze

    attr_accessor(*ALL_FIELDS)

    # Global PermissionPolicy
    attr_accessor :default_permissions

    # Global HookRegistry
    attr_accessor :default_hooks

    # Global MCP server registrations
    attr_accessor :default_mcp_servers

    # Create a new Configuration with all fields at nil/default.
    #
    # @return [Configuration]
    def self.setup
      new
    end

    def initialize
      @default_mcp_servers = {}
    end

    # Merge config defaults with per-request keyword overrides to produce an Options instance.
    #
    # nil overrides are ignored (config default wins). Explicit non-nil overrides win.
    #
    # @param overrides [Hash] Per-request keyword overrides
    # @return [Options]
    def to_options(**overrides)
      merged = {}

      ALL_FIELDS.each do |field|
        config_val = public_send(field)
        override_val = overrides.key?(field) ? overrides[field] : nil

        # Per-request override wins if provided; config default otherwise
        if overrides.key?(field)
          merged[field] = override_val
        elsif !config_val.nil?
          merged[field] = config_val
        end
      end

      # Forward any extra keys not in ALL_FIELDS (e.g., can_use_tool, permission_queue, etc.)
      overrides.each do |key, value|
        merged[key] = value unless ALL_FIELDS.include?(key)
      end

      # Wire in global permissions if no per-request can_use_tool provided
      if default_permissions && !merged.key?(:can_use_tool) && !default_permissions.empty?
        merged[:can_use_tool] = default_permissions.to_can_use_tool
      end

      # Wire in global hooks (additive merge with per-request hooks)
      if default_hooks && !default_hooks.empty?
        request_hooks = merged[:hooks]
        global_hooks = default_hooks.to_hooks_hash
        if request_hooks.is_a?(Hash)
          # Merge: global + request (request hooks take precedence for same event)
          combined = global_hooks.dup
          request_hooks.each do |event, matchers|
            combined[event] = (combined[event] || []) + Array(matchers)
          end
          merged[:hooks] = combined
        else
          merged[:hooks] = global_hooks
        end
      end

      # Wire in global MCP servers
      if !default_mcp_servers.empty? && !merged.key?(:mcp_servers)
        merged[:mcp_servers] = default_mcp_servers.dup
      end

      Options.new(**merged)
    end
  end
end
