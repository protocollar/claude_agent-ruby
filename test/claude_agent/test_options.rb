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
    %w[default acceptEdits plan delegate dontAsk].each do |mode|
      options = ClaudeAgent::Options.new(permission_mode: mode)
      assert_equal mode, options.permission_mode
    end
  end

  test "delegate_permission_mode" do
    options = ClaudeAgent::Options.new(permission_mode: "delegate")
    assert_equal "delegate", options.permission_mode
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
end
