# frozen_string_literal: true

require "json"

module ClaudeAgent
  class Options
    # Converts Options into CLI arguments and environment variables.
    #
    # Separated from Options to keep configuration concerns (what to store)
    # distinct from serialization concerns (how to render for the CLI).
    module Serializer
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
          args.concat(sandbox_args)
          args.concat(environment_args)
          args.concat(output_args)
          args.concat(debug_args)
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
          args.push("--session-id", session_id) if session_id
        end
      end

      def limits_args
        [].tap do |args|
          args.push("--max-turns", max_turns.to_s) if max_turns
          args.push("--max-budget-usd", max_budget_usd.to_s) if max_budget_usd
          args.concat(thinking_args)
          args.push("--max-thinking-tokens", max_thinking_tokens.to_s) if !thinking && max_thinking_tokens
          args.push("--effort", effort) if effort
          args.push("--strict-mcp-config") if strict_mcp_config
        end
      end

      def thinking_args
        return [] unless thinking.is_a?(Hash)

        type = thinking[:type] || thinking["type"]
        case type
        when "disabled"
          [ "--max-thinking-tokens", "0" ]
        when "enabled"
          budget = thinking[:budgetTokens] || thinking[:budget_tokens] ||
                   thinking["budgetTokens"] || thinking["budget_tokens"]
          budget ? [ "--max-thinking-tokens", budget.to_s ] : []
        else # "adaptive" or unrecognized — omit flag, let CLI use default
          []
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

      def sandbox_args
        [].tap do |args|
          if sandbox
            args.push("--sandbox", JSON.generate(sandbox.to_h))
          end
        end
      end

      def environment_args
        [].tap do |args|
          args.push("--agent", agent) if agent
          add_dirs.each { |dir| args.push("--add-dir", dir.to_s) }
          args.push("--setting-sources", setting_sources.join(",")) if setting_sources&.any?
          if settings
            case settings
            when String then args.push("--settings", settings)
            when Hash then args.push("--settings", JSON.generate(settings))
            end
          end
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
          args.push("--prompt-suggestions") if prompt_suggestions
          if agents
            agents_hash = agents.transform_values(&:to_h)
            args.push("--agents", JSON.generate(agents_hash))
          end
        end
      end

      def debug_args
        [].tap do |args|
          args.push("--debug") if debug
          args.push("--debug-file", debug_file) if debug_file
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
    end
  end
end
