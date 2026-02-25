# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentOptions < ActiveSupport::TestCase
  test "default_options" do
    options = ClaudeAgent::Options.new
    assert_nil options.model
    assert_nil options.system_prompt
    assert_equal [], options.allowed_tools
    assert_equal [], options.disallowed_tools
    assert_equal false, options.continue_conversation
    assert_equal({}, options.mcp_servers)
    assert_equal({}, options.env)
  end

  test "options_with_values" do
    options = ClaudeAgent::Options.new(
      model: "claude-sonnet-4-5-20250514",
      system_prompt: "You are helpful",
      max_turns: 10,
      max_budget_usd: 1.5
    )
    assert_equal "claude-sonnet-4-5-20250514", options.model
    assert_equal "You are helpful", options.system_prompt
    assert_equal 10, options.max_turns
    assert_equal 1.5, options.max_budget_usd
  end

  test "invalid_permission_mode" do
    assert_raises(ClaudeAgent::ConfigurationError) do
      ClaudeAgent::Options.new(permission_mode: "invalid")
    end
  end

  test "valid_permission_modes" do
    %w[default acceptEdits plan dontAsk].each do |mode|
      options = ClaudeAgent::Options.new(permission_mode: mode)
      assert_equal mode, options.permission_mode
    end
  end

  test "dont_ask_permission_mode" do
    options = ClaudeAgent::Options.new(permission_mode: "dontAsk")
    assert_equal "dontAsk", options.permission_mode
  end

  test "bypass_permissions_requires_flag" do
    # bypassPermissions mode requires explicit allow flag
    assert_raises(ClaudeAgent::ConfigurationError) do
      ClaudeAgent::Options.new(permission_mode: "bypassPermissions")
    end
  end

  test "bypass_permissions_with_flag" do
    options = ClaudeAgent::Options.new(
      permission_mode: "bypassPermissions",
      allow_dangerously_skip_permissions: true
    )
    assert_equal "bypassPermissions", options.permission_mode
    assert options.allow_dangerously_skip_permissions
  end

  test "allow_dangerously_skip_permissions_default" do
    options = ClaudeAgent::Options.new
    assert_equal false, options.allow_dangerously_skip_permissions
  end

  test "invalid_can_use_tool" do
    assert_raises(ClaudeAgent::ConfigurationError) do
      ClaudeAgent::Options.new(can_use_tool: "not callable")
    end
  end

  test "valid_can_use_tool_with_proc" do
    callback = ->(name, input, context) { { behavior: "allow" } }
    options = ClaudeAgent::Options.new(can_use_tool: callback)
    assert_equal callback, options.can_use_tool
  end

  # --- can_use_tool auto-sets permission_prompt_tool_name ---

  test "can_use_tool auto sets permission_prompt_tool_name to stdio" do
    options = ClaudeAgent::Options.new(
      can_use_tool: ->(name, input, context) { { behavior: "allow" } }
    )
    assert_equal "stdio", options.permission_prompt_tool_name
  end

  test "can_use_tool does not override explicit permission_prompt_tool_name" do
    options = ClaudeAgent::Options.new(
      can_use_tool: ->(name, input, context) { { behavior: "allow" } },
      permission_prompt_tool_name: "custom-tool"
    )
    assert_equal "custom-tool", options.permission_prompt_tool_name
  end

  test "permission_prompt_tool_name nil without can_use_tool" do
    options = ClaudeAgent::Options.new
    assert_nil options.permission_prompt_tool_name
  end

  test "to_cli_args_includes_permission_prompt_tool_with_can_use_tool" do
    options = ClaudeAgent::Options.new(
      can_use_tool: ->(name, input, context) { { behavior: "allow" } }
    )
    args = options.to_cli_args
    assert_includes args, "--permission-prompt-tool"
    idx = args.index("--permission-prompt-tool")
    assert_equal "stdio", args[idx + 1]
  end

  test "invalid_max_turns" do
    assert_raises(ClaudeAgent::ConfigurationError) do
      ClaudeAgent::Options.new(max_turns: 0)
    end
    assert_raises(ClaudeAgent::ConfigurationError) do
      ClaudeAgent::Options.new(max_turns: -1)
    end
  end

  test "invalid_max_budget" do
    assert_raises(ClaudeAgent::ConfigurationError) do
      ClaudeAgent::Options.new(max_budget_usd: 0)
    end
    assert_raises(ClaudeAgent::ConfigurationError) do
      ClaudeAgent::Options.new(max_budget_usd: -1)
    end
  end

  test "to_cli_args_basic" do
    options = ClaudeAgent::Options.new(
      model: "claude-sonnet-4-5-20250514",
      system_prompt: "Be helpful",
      max_turns: 5
    )
    args = options.to_cli_args
    assert_includes args, "--model"
    assert_includes args, "claude-sonnet-4-5-20250514"
    assert_includes args, "--system-prompt"
    assert_includes args, "Be helpful"
    assert_includes args, "--max-turns"
    assert_includes args, "5"
  end

  test "to_cli_args_with_tools" do
    options = ClaudeAgent::Options.new(
      tools: [ "Read", "Write", "Bash" ],
      allowed_tools: [ "Read" ],
      disallowed_tools: [ "Bash" ]
    )
    args = options.to_cli_args
    assert_includes args, "--tools"
    assert_includes args, "Read,Write,Bash"
    assert_includes args, "--allowedTools"
    assert_includes args, "Read"
    assert_includes args, "--disallowedTools"
    assert_includes args, "Bash"
  end

  test "to_cli_args_with_permission_mode" do
    options = ClaudeAgent::Options.new(permission_mode: "acceptEdits")
    args = options.to_cli_args
    assert_includes args, "--permission-mode"
    assert_includes args, "acceptEdits"
  end

  test "to_cli_args_with_continue" do
    options = ClaudeAgent::Options.new(continue_conversation: true)
    args = options.to_cli_args
    assert_includes args, "--continue"
  end

  test "to_cli_args_with_resume" do
    options = ClaudeAgent::Options.new(resume: "session-123")
    args = options.to_cli_args
    assert_includes args, "--resume"
    assert_includes args, "session-123"
  end

  test "to_env" do
    options = ClaudeAgent::Options.new(
      env: { "MY_VAR" => "value" },
      cwd: "/tmp",
      enable_file_checkpointing: true
    )
    env = options.to_env
    assert_equal "value", env["MY_VAR"]
    assert_equal "sdk-rb", env["CLAUDE_CODE_ENTRYPOINT"]
    assert_equal ClaudeAgent::VERSION, env["CLAUDE_AGENT_SDK_VERSION"]
    assert_equal "true", env["CLAUDE_CODE_ENABLE_SDK_FILE_CHECKPOINTING"]
    assert_equal "/tmp", env["PWD"]
  end

  test "has_sdk_mcp_servers" do
    options = ClaudeAgent::Options.new
    refute options.has_sdk_mcp_servers?

    options = ClaudeAgent::Options.new(mcp_servers: {
      "server1" => { type: "stdio", command: "node" },
      "server2" => { type: "sdk", instance: Object.new }
    })
    assert options.has_sdk_mcp_servers?
  end

  test "has_hooks" do
    options = ClaudeAgent::Options.new
    refute options.has_hooks?

    options = ClaudeAgent::Options.new(hooks: { "PreToolUse" => [] })
    assert options.has_hooks?
  end

  test "to_cli_args_with_dangerously_skip_permissions" do
    options = ClaudeAgent::Options.new(
      permission_mode: "bypassPermissions",
      allow_dangerously_skip_permissions: true
    )
    args = options.to_cli_args
    assert_includes args, "--dangerously-skip-permissions"
  end

  test "to_cli_args_with_tools_preset" do
    preset = ClaudeAgent::ToolsPreset.new(preset: "claude_code")
    options = ClaudeAgent::Options.new(tools: preset)
    args = options.to_cli_args
    assert_includes args, "--tools"

    # Find the tools argument value
    tools_index = args.index("--tools")
    tools_value = args[tools_index + 1]
    parsed = JSON.parse(tools_value)
    assert_equal "preset", parsed["type"]
    assert_equal "claude_code", parsed["preset"]
  end

  test "to_cli_args_with_tools_preset_hash" do
    options = ClaudeAgent::Options.new(tools: { type: "preset", preset: "claude_code" })
    args = options.to_cli_args
    assert_includes args, "--tools"

    tools_index = args.index("--tools")
    tools_value = args[tools_index + 1]
    parsed = JSON.parse(tools_value)
    assert_equal "preset", parsed["type"]
    assert_equal "claude_code", parsed["preset"]
  end

  # --- Persist Session ---

  test "persist_session_default_true" do
    options = ClaudeAgent::Options.new
    assert_equal true, options.persist_session
  end

  test "persist_session_explicit_true" do
    options = ClaudeAgent::Options.new(persist_session: true)
    assert_equal true, options.persist_session
  end

  test "persist_session_explicit_false" do
    options = ClaudeAgent::Options.new(persist_session: false)
    assert_equal false, options.persist_session
  end

  test "to_cli_args_persist_session_default" do
    options = ClaudeAgent::Options.new
    args = options.to_cli_args
    refute_includes args, "--no-persist-session"
  end

  test "to_cli_args_persist_session_true" do
    options = ClaudeAgent::Options.new(persist_session: true)
    args = options.to_cli_args
    refute_includes args, "--no-persist-session"
  end

  test "to_cli_args_persist_session_false" do
    options = ClaudeAgent::Options.new(persist_session: false)
    args = options.to_cli_args
    assert_includes args, "--no-persist-session"
  end

  # --- Agent Definitions ---

  test "agents_option" do
    agents = {
      "test-runner" => ClaudeAgent::AgentDefinition.new(
        description: "Runs tests",
        prompt: "You run tests",
        tools: [ "Bash" ],
        model: "haiku"
      )
    }
    options = ClaudeAgent::Options.new(agents: agents)
    assert_equal agents, options.agents
  end

  test "to_cli_args_with_agents" do
    agents = {
      "my-agent" => ClaudeAgent::AgentDefinition.new(
        description: "Test agent",
        prompt: "Do testing"
      )
    }
    options = ClaudeAgent::Options.new(agents: agents)
    args = options.to_cli_args
    assert_includes args, "--agents"

    agents_index = args.index("--agents")
    agents_value = args[agents_index + 1]
    parsed = JSON.parse(agents_value)
    assert_equal "Test agent", parsed["my-agent"]["description"]
    assert_equal "Do testing", parsed["my-agent"]["prompt"]
  end

  test "to_cli_args_with_agents_as_hash" do
    agents = {
      "simple-agent" => {
        description: "Simple",
        prompt: "Help"
      }
    }
    options = ClaudeAgent::Options.new(agents: agents)
    args = options.to_cli_args
    assert_includes args, "--agents"
  end

  # --- Agent (main thread) ---

  test "agent_option" do
    options = ClaudeAgent::Options.new(agent: "my-custom-agent")
    assert_equal "my-custom-agent", options.agent
  end

  test "agent_option_default_nil" do
    options = ClaudeAgent::Options.new
    assert_nil options.agent
  end

  test "to_cli_args_with_agent" do
    options = ClaudeAgent::Options.new(agent: "test-agent")
    args = options.to_cli_args
    assert_includes args, "--agent"
    assert_includes args, "test-agent"
  end

  test "to_cli_args_without_agent" do
    options = ClaudeAgent::Options.new
    args = options.to_cli_args
    refute_includes args, "--agent"
  end

  # --- Sandbox ---

  test "sandbox_option" do
    sandbox = ClaudeAgent::SandboxSettings.new(enabled: true)
    options = ClaudeAgent::Options.new(sandbox: sandbox)
    assert_equal sandbox, options.sandbox
  end

  test "to_cli_args_with_sandbox" do
    sandbox = ClaudeAgent::SandboxSettings.new(
      enabled: true,
      auto_allow_bash_if_sandboxed: true
    )
    options = ClaudeAgent::Options.new(sandbox: sandbox)
    args = options.to_cli_args
    assert_includes args, "--sandbox"

    sandbox_index = args.index("--sandbox")
    sandbox_value = args[sandbox_index + 1]
    parsed = JSON.parse(sandbox_value)
    assert parsed["enabled"]
    assert parsed["autoAllowBashIfSandboxed"]
  end

  # --- Setup Hook Options ---

  test "init_option_default_false" do
    options = ClaudeAgent::Options.new
    assert_equal false, options.init
  end

  test "init_only_option_default_false" do
    options = ClaudeAgent::Options.new
    assert_equal false, options.init_only
  end

  test "maintenance_option_default_false" do
    options = ClaudeAgent::Options.new
    assert_equal false, options.maintenance
  end

  test "to_cli_args_with_init" do
    options = ClaudeAgent::Options.new(init: true)
    args = options.to_cli_args
    assert_includes args, "--init"
    refute_includes args, "--init-only"
    refute_includes args, "--maintenance"
  end

  test "to_cli_args_with_init_only" do
    options = ClaudeAgent::Options.new(init_only: true)
    args = options.to_cli_args
    assert_includes args, "--init-only"
    refute_includes args, "--init"
    refute_includes args, "--maintenance"
  end

  test "to_cli_args_with_maintenance" do
    options = ClaudeAgent::Options.new(maintenance: true)
    args = options.to_cli_args
    assert_includes args, "--maintenance"
    refute_includes args, "--init"
    refute_includes args, "--init-only"
  end

  test "to_cli_args_without_setup_options" do
    options = ClaudeAgent::Options.new
    args = options.to_cli_args
    refute_includes args, "--init"
    refute_includes args, "--init-only"
    refute_includes args, "--maintenance"
  end

  test "raises_when_multiple_setup_options_set" do
    error = assert_raises(ClaudeAgent::ConfigurationError) do
      ClaudeAgent::Options.new(init: true, init_only: true)
    end
    assert_match(/Only one of init, init_only, or maintenance/, error.message)
  end

  test "raises_when_init_and_maintenance_set" do
    error = assert_raises(ClaudeAgent::ConfigurationError) do
      ClaudeAgent::Options.new(init: true, maintenance: true)
    end
    assert_match(/Only one of init, init_only, or maintenance/, error.message)
  end

  test "raises_when_all_setup_options_set" do
    error = assert_raises(ClaudeAgent::ConfigurationError) do
      ClaudeAgent::Options.new(init: true, init_only: true, maintenance: true)
    end
    assert_match(/Only one of init, init_only, or maintenance/, error.message)
  end

  # --- Session ID ---

  test "session_id_option_default_nil" do
    options = ClaudeAgent::Options.new
    assert_nil options.session_id
  end

  test "session_id_option_with_value" do
    options = ClaudeAgent::Options.new(session_id: "custom-uuid-123")
    assert_equal "custom-uuid-123", options.session_id
  end

  test "to_cli_args_with_session_id" do
    options = ClaudeAgent::Options.new(session_id: "my-session")
    args = options.to_cli_args
    assert_includes args, "--session-id"
    assert_includes args, "my-session"
  end

  test "to_cli_args_without_session_id" do
    options = ClaudeAgent::Options.new
    args = options.to_cli_args
    refute_includes args, "--session-id"
  end

  test "session_id_with_continue_raises_without_fork" do
    assert_raises(ClaudeAgent::ConfigurationError) do
      ClaudeAgent::Options.new(session_id: "abc", continue_conversation: true)
    end
  end

  test "session_id_with_resume_raises_without_fork" do
    assert_raises(ClaudeAgent::ConfigurationError) do
      ClaudeAgent::Options.new(session_id: "abc", resume: "sess-123")
    end
  end

  test "session_id_with_continue_and_fork_is_valid" do
    options = ClaudeAgent::Options.new(
      session_id: "abc",
      continue_conversation: true,
      fork_session: true
    )
    assert_equal "abc", options.session_id
  end

  test "session_id_with_resume_and_fork_is_valid" do
    options = ClaudeAgent::Options.new(
      session_id: "abc",
      resume: "sess-123",
      fork_session: true
    )
    assert_equal "abc", options.session_id
  end

  # --- Thinking Option ---

  test "thinking_option_default_nil" do
    options = ClaudeAgent::Options.new
    assert_nil options.thinking
  end

  test "thinking_option_adaptive" do
    options = ClaudeAgent::Options.new(thinking: { type: "adaptive" })
    assert_equal({ type: "adaptive" }, options.thinking)
  end

  test "thinking_option_enabled_with_budget" do
    options = ClaudeAgent::Options.new(thinking: { type: "enabled", budgetTokens: 10_000 })
    assert_equal({ type: "enabled", budgetTokens: 10_000 }, options.thinking)
  end

  test "thinking_option_disabled" do
    options = ClaudeAgent::Options.new(thinking: { type: "disabled" })
    assert_equal({ type: "disabled" }, options.thinking)
  end

  test "thinking_option_with_string_keys" do
    options = ClaudeAgent::Options.new(thinking: { "type" => "adaptive" })
    assert_equal({ "type" => "adaptive" }, options.thinking)
  end

  test "thinking_option_invalid_type_raises" do
    assert_raises(ClaudeAgent::ConfigurationError) do
      ClaudeAgent::Options.new(thinking: { type: "invalid" })
    end
  end

  test "thinking_option_non_hash_raises" do
    assert_raises(ClaudeAgent::ConfigurationError) do
      ClaudeAgent::Options.new(thinking: "adaptive")
    end
  end

  test "to_cli_args_thinking_adaptive_omits_flag" do
    options = ClaudeAgent::Options.new(thinking: { type: "adaptive" })
    args = options.to_cli_args
    refute_includes args, "--max-thinking-tokens"
  end

  test "to_cli_args_thinking_enabled_sets_budget" do
    options = ClaudeAgent::Options.new(thinking: { type: "enabled", budgetTokens: 8000 })
    args = options.to_cli_args
    assert_includes args, "--max-thinking-tokens"
    idx = args.index("--max-thinking-tokens")
    assert_equal "8000", args[idx + 1]
  end

  test "to_cli_args_thinking_enabled_with_snake_case_key" do
    options = ClaudeAgent::Options.new(thinking: { type: "enabled", budget_tokens: 5000 })
    args = options.to_cli_args
    assert_includes args, "--max-thinking-tokens"
    idx = args.index("--max-thinking-tokens")
    assert_equal "5000", args[idx + 1]
  end

  test "to_cli_args_thinking_disabled_sets_zero" do
    options = ClaudeAgent::Options.new(thinking: { type: "disabled" })
    args = options.to_cli_args
    assert_includes args, "--max-thinking-tokens"
    idx = args.index("--max-thinking-tokens")
    assert_equal "0", args[idx + 1]
  end

  test "thinking_takes_precedence_over_max_thinking_tokens" do
    options = ClaudeAgent::Options.new(
      thinking: { type: "disabled" },
      max_thinking_tokens: 10_000
    )
    args = options.to_cli_args
    # thinking should produce --max-thinking-tokens 0, and the standalone max_thinking_tokens should be suppressed
    token_indices = args.each_index.select { |i| args[i] == "--max-thinking-tokens" }
    assert_equal 1, token_indices.size
    assert_equal "0", args[token_indices.first + 1]
  end

  test "max_thinking_tokens_used_when_thinking_not_set" do
    options = ClaudeAgent::Options.new(max_thinking_tokens: 5000)
    args = options.to_cli_args
    assert_includes args, "--max-thinking-tokens"
    idx = args.index("--max-thinking-tokens")
    assert_equal "5000", args[idx + 1]
  end

  # --- Effort Option ---

  test "effort_option_default_nil" do
    options = ClaudeAgent::Options.new
    assert_nil options.effort
  end

  test "effort_option_valid_values" do
    %w[low medium high max].each do |level|
      options = ClaudeAgent::Options.new(effort: level)
      assert_equal level, options.effort
    end
  end

  test "effort_option_invalid_raises" do
    assert_raises(ClaudeAgent::ConfigurationError) do
      ClaudeAgent::Options.new(effort: "extreme")
    end
  end

  test "to_cli_args_with_effort" do
    options = ClaudeAgent::Options.new(effort: "high")
    args = options.to_cli_args
    assert_includes args, "--effort"
    idx = args.index("--effort")
    assert_equal "high", args[idx + 1]
  end

  test "to_cli_args_without_effort" do
    options = ClaudeAgent::Options.new
    args = options.to_cli_args
    refute_includes args, "--effort"
  end

  # --- Debug Options ---

  test "debug_option_default_false" do
    options = ClaudeAgent::Options.new
    assert_equal false, options.debug
  end

  test "debug_file_option_default_nil" do
    options = ClaudeAgent::Options.new
    assert_nil options.debug_file
  end

  test "debug_option_explicit_true" do
    options = ClaudeAgent::Options.new(debug: true)
    assert_equal true, options.debug
  end

  test "debug_file_option_with_path" do
    options = ClaudeAgent::Options.new(debug_file: "/tmp/claude-debug.log")
    assert_equal "/tmp/claude-debug.log", options.debug_file
  end

  test "to_cli_args_with_debug" do
    options = ClaudeAgent::Options.new(debug: true)
    args = options.to_cli_args
    assert_includes args, "--debug"
    refute_includes args, "--debug-file"
  end

  test "to_cli_args_with_debug_file" do
    options = ClaudeAgent::Options.new(debug_file: "/tmp/debug.log")
    args = options.to_cli_args
    assert_includes args, "--debug-file"
    assert_includes args, "/tmp/debug.log"
  end

  test "to_cli_args_with_debug_and_debug_file" do
    options = ClaudeAgent::Options.new(debug: true, debug_file: "/tmp/debug.log")
    args = options.to_cli_args
    assert_includes args, "--debug"
    assert_includes args, "--debug-file"
    assert_includes args, "/tmp/debug.log"
  end

  test "to_cli_args_without_debug_options" do
    options = ClaudeAgent::Options.new
    args = options.to_cli_args
    refute_includes args, "--debug"
    refute_includes args, "--debug-file"
  end

  # --- Permission Queue ---

  test "permission_queue_default_nil" do
    options = ClaudeAgent::Options.new
    assert_nil options.permission_queue
  end

  test "permission_queue_explicit_true" do
    options = ClaudeAgent::Options.new(permission_queue: true)
    assert_equal true, options.permission_queue
  end

  test "permission_queue_auto_sets_permission_prompt_tool_name" do
    options = ClaudeAgent::Options.new(permission_queue: true)
    assert_equal "stdio", options.permission_prompt_tool_name
  end

  test "permission_queue_does_not_override_explicit_permission_prompt_tool_name" do
    options = ClaudeAgent::Options.new(
      permission_queue: true,
      permission_prompt_tool_name: "custom"
    )
    assert_equal "custom", options.permission_prompt_tool_name
  end

  test "to_cli_args_includes_permission_prompt_tool_with_permission_queue" do
    options = ClaudeAgent::Options.new(permission_queue: true)
    args = options.to_cli_args
    assert_includes args, "--permission-prompt-tool"
    idx = args.index("--permission-prompt-tool")
    assert_equal "stdio", args[idx + 1]
  end

  # --- Prompt Suggestions ---

  test "prompt_suggestions_default_false" do
    options = ClaudeAgent::Options.new
    assert_equal false, options.prompt_suggestions
  end

  test "prompt_suggestions_explicit_true" do
    options = ClaudeAgent::Options.new(prompt_suggestions: true)
    assert_equal true, options.prompt_suggestions
  end

  test "to_cli_args_with_prompt_suggestions" do
    options = ClaudeAgent::Options.new(prompt_suggestions: true)
    args = options.to_cli_args
    assert_includes args, "--prompt-suggestions"
  end

  test "to_cli_args_without_prompt_suggestions" do
    options = ClaudeAgent::Options.new
    args = options.to_cli_args
    refute_includes args, "--prompt-suggestions"
  end
end
