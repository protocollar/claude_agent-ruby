# frozen_string_literal: true

require_relative "../integration_helper"

class TestIntegrationOptions < IntegrationTestCase
  test "options to CLI args" do
    options = ClaudeAgent::Options.new(
      max_turns: 5,
      system_prompt: "Be helpful",
      permission_mode: "acceptEdits"
    )

    args = options.to_cli_args
    assert args.include?("--max-turns"), "Expected --max-turns"
    assert args.include?("5")
    assert args.include?("--system-prompt")
    assert args.include?("Be helpful")
    assert args.include?("--permission-mode")
    assert args.include?("acceptEdits")
  end

  test "options to env" do
    options = ClaudeAgent::Options.new
    env = options.to_env

    assert_equal "sdk-rb", env["CLAUDE_CODE_ENTRYPOINT"]
    assert_equal ClaudeAgent::VERSION, env["CLAUDE_AGENT_SDK_VERSION"]
  end

  test "options resume_session_at field" do
    options = ClaudeAgent::Options.new(
      resume_session_at: "msg_uuid_123"
    )

    assert_equal "msg_uuid_123", options.resume_session_at
    args = options.to_cli_args
    assert args.include?("--resume-session-at")
    assert args.include?("msg_uuid_123")
  end

  test "options strict_mcp_config field" do
    options = ClaudeAgent::Options.new(
      strict_mcp_config: true
    )

    assert_equal true, options.strict_mcp_config
    args = options.to_cli_args
    assert args.include?("--strict-mcp-config")
  end

  test "options system_prompt preset format" do
    options = ClaudeAgent::Options.new(
      system_prompt: {
        type: "preset",
        preset: "claude_code",
        append: "Additional instructions"
      }
    )

    args = options.to_cli_args
    assert args.include?("--system-prompt")
    idx = args.index("--system-prompt")
    prompt_value = args[idx + 1]
    assert prompt_value.include?("preset")
    assert prompt_value.include?("claude_code")
  end

  test "options sandbox CLI args" do
    sandbox = ClaudeAgent::SandboxSettings.new(
      enabled: true,
      auto_allow_bash_if_sandboxed: true
    )

    options = ClaudeAgent::Options.new(sandbox: sandbox)
    args = options.to_cli_args

    assert args.include?("--sandbox")
    idx = args.index("--sandbox")
    sandbox_value = args[idx + 1]
    assert sandbox_value.include?("enabled")
  end

  test "options persist_session field" do
    default_options = ClaudeAgent::Options.new
    assert_equal true, default_options.persist_session

    no_persist = ClaudeAgent::Options.new(persist_session: false)
    assert_equal false, no_persist.persist_session

    args = no_persist.to_cli_args
    assert args.include?("--no-persist-session")

    persist = ClaudeAgent::Options.new(persist_session: true)
    args = persist.to_cli_args
    assert !args.include?("--no-persist-session")
  end

  test "options delegate permission mode" do
    options = ClaudeAgent::Options.new(permission_mode: "delegate")
    assert_equal "delegate", options.permission_mode

    args = options.to_cli_args
    assert args.include?("--permission-mode")
    assert args.include?("delegate")
  end

  test "options dontAsk permission mode" do
    options = ClaudeAgent::Options.new(permission_mode: "dontAsk")
    assert_equal "dontAsk", options.permission_mode

    args = options.to_cli_args
    assert args.include?("--permission-mode")
    assert args.include?("dontAsk")
  end

  test "options allow_dangerously_skip_permissions" do
    options = ClaudeAgent::Options.new
    assert_equal false, options.allow_dangerously_skip_permissions

    assert_raises(ClaudeAgent::ConfigurationError) do
      ClaudeAgent::Options.new(permission_mode: "bypassPermissions")
    end

    bypass_options = ClaudeAgent::Options.new(
      permission_mode: "bypassPermissions",
      allow_dangerously_skip_permissions: true
    )
    assert_equal "bypassPermissions", bypass_options.permission_mode
    assert_equal true, bypass_options.allow_dangerously_skip_permissions

    args = bypass_options.to_cli_args
    assert args.include?("--dangerously-skip-permissions")
  end
end
