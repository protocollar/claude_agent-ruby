# frozen_string_literal: true

require "json"

module ClaudeAgent
  # Permission modes for tool execution (TypeScript SDK parity)
  PERMISSION_MODES = %w[default acceptEdits plan bypassPermissions delegate dontAsk].freeze

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
      init: false,
      init_only: false,
      maintenance: false
    }.freeze

    # All configurable attributes
    ATTRIBUTES = %i[
      tools allowed_tools disallowed_tools
      system_prompt append_system_prompt
      model fallback_model
      permission_mode permission_prompt_tool_name can_use_tool allow_dangerously_skip_permissions
      continue_conversation resume fork_session resume_session_at
      max_turns max_budget_usd max_thinking_tokens
      strict_mcp_config mcp_servers hooks
      settings sandbox cwd add_dirs env user agent
      cli_path extra_args agents setting_sources plugins
      include_partial_messages output_format enable_file_checkpointing
      persist_session betas max_buffer_size stderr_callback
      abort_controller spawn_claude_code_process
      init init_only maintenance
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

    # Build CLI arguments from options
    # @return [Array<String>] CLI arguments
    def to_cli_args
      [].tap do |args|
        args.concat(system_prompt_args)
        args.concat(model_args)
        args.concat(tools_args)
        args.concat(permission_args)
        args.concat(conversation_args)
        args.concat(limits_args)
        args.concat(mcp_args)
        args.concat(settings_args)
        args.concat(environment_args)
        args.concat(output_args)
        args.concat(setup_hook_args)
        args.concat(extra_cli_args)
      end
    end

    # Build environment variables for CLI process
    # @return [Hash] Environment variables
    def to_env
      env.dup.tap do |process_env|
        process_env["CLAUDE_CODE_ENTRYPOINT"] = "sdk-rb"
        process_env["CLAUDE_AGENT_SDK_VERSION"] = ClaudeAgent::VERSION
        process_env["CLAUDE_CODE_ENABLE_SDK_FILE_CHECKPOINTING"] = "true" if enable_file_checkpointing
        process_env["PWD"] = cwd.to_s if cwd
      end
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
      hooks.is_a?(Hash) && hooks.any?
    end

    # Get the abort signal from the controller
    # @return [AbortSignal, nil]
    def abort_signal
      abort_controller&.signal
    end

    private

    # --- CLI Argument Builders ---

    def system_prompt_args
      [].tap do |args|
        if system_prompt
          case system_prompt
          when String then args.push("--system-prompt", system_prompt)
          when Hash then args.push("--system-prompt", JSON.generate(system_prompt))
          end
        end
        args.push("--append-system-prompt", append_system_prompt) if append_system_prompt
      end
    end

    def model_args
      [].tap do |args|
        args.push("--model", model) if model
        args.push("--fallback-model", fallback_model) if fallback_model
      end
    end

    def tools_args
      [].tap do |args|
        if tools
          case tools
          when Array then args.push("--tools", tools.join(","))
          when ToolsPreset then args.push("--tools", JSON.generate(tools.to_h))
          when Hash then args.push("--tools", JSON.generate(tools))
          else args.push("--tools", tools.to_s)
          end
        end
        args.push("--allowedTools", allowed_tools.join(",")) if allowed_tools.any?
        args.push("--disallowedTools", disallowed_tools.join(",")) if disallowed_tools.any?
      end
    end

    def permission_args
      [].tap do |args|
        args.push("--permission-mode", permission_mode) if permission_mode
        args.push("--permission-prompt-tool", permission_prompt_tool_name) if permission_prompt_tool_name
        args.push("--dangerously-skip-permissions") if allow_dangerously_skip_permissions
      end
    end

    def conversation_args
      [].tap do |args|
        args.push("--continue") if continue_conversation
        args.push("--resume", resume) if resume
        args.push("--fork-session") if fork_session
        args.push("--resume-session-at", resume_session_at) if resume_session_at
      end
    end

    def limits_args
      [].tap do |args|
        args.push("--max-turns", max_turns.to_s) if max_turns
        args.push("--max-budget-usd", max_budget_usd.to_s) if max_budget_usd
        args.push("--max-thinking-tokens", max_thinking_tokens.to_s) if max_thinking_tokens
        args.push("--strict-mcp-config") if strict_mcp_config
      end
    end

    def mcp_args
      [].tap do |args|
        if mcp_servers.is_a?(Hash) && mcp_servers.any?
          external_servers = mcp_servers.reject { |_, v| v.is_a?(Hash) && v[:type] == "sdk" }
          args.push("--mcp-config", JSON.generate(external_servers)) if external_servers.any?
        elsif mcp_servers.is_a?(String)
          args.push("--mcp-config", mcp_servers)
        end
      end
    end

    def settings_args
      [].tap do |args|
        args.push("--settings", settings) if settings
        if sandbox
          sandbox_json = sandbox.respond_to?(:to_h) ? sandbox.to_h : sandbox
          args.push("--sandbox", JSON.generate(sandbox_json))
        end
      end
    end

    def environment_args
      [].tap do |args|
        args.push("--user", user) if user
        args.push("--agent", agent) if agent
        add_dirs.each { |dir| args.push("--add-dir", dir.to_s) }
        args.push("--setting-sources", setting_sources.join(",")) if setting_sources&.any?
        plugins.each do |plugin|
          dir = plugin.is_a?(Hash) ? plugin[:dir] : plugin
          args.push("--plugin-dir", dir.to_s)
        end
        args.push("--betas", betas.join(",")) if betas.any?
      end
    end

    def output_args
      [].tap do |args|
        args.push("--enable-file-checkpointing") if enable_file_checkpointing
        args.push("--no-persist-session") if persist_session == false
        args.push("--json-schema", JSON.generate(output_format)) if output_format
        args.push("--include-partial-messages") if include_partial_messages
        if agents
          agents_hash = agents.transform_values { |a| a.respond_to?(:to_h) ? a.to_h : a }
          args.push("--agents", JSON.generate(agents_hash))
        end
      end
    end

    def setup_hook_args
      [].tap do |args|
        args.push("--init") if init
        args.push("--init-only") if init_only
        args.push("--maintenance") if maintenance
      end
    end

    def extra_cli_args
      [].tap do |args|
        extra_args.each do |key, value|
          flag = key.to_s.start_with?("--") ? key.to_s : "--#{key}"
          value.nil? ? args.push(flag) : args.push(flag, value.to_s)
        end
      end
    end

    # --- Validation ---

    def validate!
      if permission_mode && !PERMISSION_MODES.include?(permission_mode)
        raise ConfigurationError, "Invalid permission_mode: #{permission_mode}. Must be one of: #{PERMISSION_MODES.join(", ")}"
      end

      if permission_mode == "bypassPermissions" && !allow_dangerously_skip_permissions
        raise ConfigurationError,
              "Must set allow_dangerously_skip_permissions: true to use bypassPermissions mode"
      end

      if can_use_tool && !can_use_tool.respond_to?(:call)
        raise ConfigurationError, "can_use_tool must be callable (Proc, Lambda, or object responding to #call)"
      end

      if max_turns && (!max_turns.is_a?(Integer) || max_turns < 1)
        raise ConfigurationError, "max_turns must be a positive integer"
      end

      if max_budget_usd && (!max_budget_usd.is_a?(Numeric) || max_budget_usd <= 0)
        raise ConfigurationError, "max_budget_usd must be a positive number"
      end

      setup_options = [ init, init_only, maintenance ].count { |opt| opt }
      if setup_options > 1
        raise ConfigurationError, "Only one of init, init_only, or maintenance can be set at a time"
      end
    end
  end
end
