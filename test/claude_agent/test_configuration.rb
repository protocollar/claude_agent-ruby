# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentConfiguration < ActiveSupport::TestCase
  setup do
    @original_config = ClaudeAgent.config
    ClaudeAgent.reset_config!
  end

  teardown do
    ClaudeAgent.instance_variable_set(:@config, @original_config)
  end

  # --- Configuration defaults ---

  test "config starts with nil fields" do
    config = ClaudeAgent::Configuration.setup
    assert_nil config.model
    assert_nil config.permission_mode
    assert_nil config.max_turns
    assert_nil config.system_prompt
  end

  # --- Module-level delegators ---

  test "module-level model setter and getter" do
    ClaudeAgent.model = "opus"
    assert_equal "opus", ClaudeAgent.model
  end

  test "module-level permission_mode" do
    ClaudeAgent.permission_mode = "acceptEdits"
    assert_equal "acceptEdits", ClaudeAgent.permission_mode
  end

  test "module-level max_turns" do
    ClaudeAgent.max_turns = 10
    assert_equal 10, ClaudeAgent.max_turns
  end

  test "module-level system_prompt" do
    ClaudeAgent.system_prompt = "Be helpful"
    assert_equal "Be helpful", ClaudeAgent.system_prompt
  end

  test "module-level effort" do
    ClaudeAgent.effort = "high"
    assert_equal "high", ClaudeAgent.effort
  end

  # --- Block-based configure ---

  test "configure block sets fields" do
    ClaudeAgent.configure do |c|
      c.model = "opus"
      c.max_turns = 5
      c.system_prompt = "You are helpful"
    end

    assert_equal "opus", ClaudeAgent.model
    assert_equal 5, ClaudeAgent.max_turns
    assert_equal "You are helpful", ClaudeAgent.system_prompt
  end

  # --- reset_config! ---

  test "reset_config! clears all fields" do
    ClaudeAgent.model = "opus"
    ClaudeAgent.max_turns = 10
    ClaudeAgent.reset_config!

    assert_nil ClaudeAgent.model
    assert_nil ClaudeAgent.max_turns
  end

  # --- to_options ---

  test "to_options merges config defaults" do
    config = ClaudeAgent::Configuration.setup
    config.model = "opus"
    config.max_turns = 10

    options = config.to_options
    assert_equal "opus", options.model
    assert_equal 10, options.max_turns
  end

  test "to_options per-request overrides win" do
    config = ClaudeAgent::Configuration.setup
    config.model = "opus"
    config.max_turns = 10

    options = config.to_options(model: "sonnet", max_turns: 5)
    assert_equal "sonnet", options.model
    assert_equal 5, options.max_turns
  end

  test "to_options nil config values do not override Options defaults" do
    config = ClaudeAgent::Configuration.setup
    options = config.to_options

    # Options defaults should still be in effect
    assert_equal [], options.allowed_tools
    assert_equal({}, options.mcp_servers)
    assert_equal true, options.persist_session
  end

  test "to_options forwards extra keys" do
    config = ClaudeAgent::Configuration.setup
    callback = ->(name, input, ctx) { { behavior: "allow" } }

    options = config.to_options(can_use_tool: callback)
    assert_equal callback, options.can_use_tool
  end

  test "to_options wires default_permissions" do
    config = ClaudeAgent::Configuration.setup
    config.default_permissions = ClaudeAgent::PermissionPolicy.new do |p|
      p.allow "Read"
      p.deny_all
    end

    options = config.to_options
    assert_not_nil options.can_use_tool
    assert options.can_use_tool.respond_to?(:call)

    # Verify the compiled lambda works
    result = options.can_use_tool.call("Read", {}, nil)
    assert_equal "allow", result.behavior

    result = options.can_use_tool.call("Bash", {}, nil)
    assert_equal "deny", result.behavior
  end

  test "to_options skips default_permissions when can_use_tool provided" do
    config = ClaudeAgent::Configuration.setup
    config.default_permissions = ClaudeAgent::PermissionPolicy.new { |p| p.deny_all }

    custom = ->(name, input, ctx) { ClaudeAgent::PermissionResultAllow.new }
    options = config.to_options(can_use_tool: custom)
    assert_equal custom, options.can_use_tool
  end

  test "to_options wires default_hooks" do
    config = ClaudeAgent::Configuration.setup
    config.default_hooks = ClaudeAgent::HookRegistry.new do |h|
      h.before_tool_use("Bash") { |_, _| { continue_: true } }
    end

    options = config.to_options
    assert options.has_hooks?
    assert options.hooks.key?("PreToolUse")
  end

  test "to_options wires default_mcp_servers" do
    config = ClaudeAgent::Configuration.setup
    config.default_mcp_servers["calc"] = { type: "sdk", name: "calc" }

    options = config.to_options
    assert_equal({ "calc" => { type: "sdk", name: "calc" } }, options.mcp_servers)
  end

  # --- ask ---

  test "ask builds options from config" do
    ClaudeAgent.model = "opus"

    # Mock the query_turn method to capture what Options are built
    options_captured = nil
    ClaudeAgent.stubs(:query_turn).with do |prompt:, options:, events:|
      options_captured = options
      true
    end.returns(ClaudeAgent::TurnResult.new)

    ClaudeAgent.ask("test")
    assert_equal "opus", options_captured.model
  end

  test "ask per-request overrides" do
    ClaudeAgent.model = "opus"

    options_captured = nil
    ClaudeAgent.stubs(:query_turn).with do |prompt:, options:, events:|
      options_captured = options
      true
    end.returns(ClaudeAgent::TurnResult.new)

    ClaudeAgent.ask("test", model: "sonnet")
    assert_equal "sonnet", options_captured.model
  end

  test "ask bypasses config with explicit options" do
    ClaudeAgent.model = "opus"

    explicit = ClaudeAgent::Options.new(model: "haiku")
    options_captured = nil
    ClaudeAgent.stubs(:query_turn).with do |prompt:, options:, events:|
      options_captured = options
      true
    end.returns(ClaudeAgent::TurnResult.new)

    ClaudeAgent.ask("test", options: explicit)
    assert_equal "haiku", options_captured.model
  end

  # --- chat ---

  test "chat without block returns Conversation" do
    result = ClaudeAgent.chat
    assert_instance_of ClaudeAgent::Conversation, result
    result.close rescue nil
  end

  test "chat with block yields and auto-closes" do
    transport = MockTransport.new
    client = ClaudeAgent::Client.new(transport: transport)
    conversation_ref = nil

    transport.add_response({
      "type" => "assistant",
      "message" => { "role" => "assistant", "content" => [ { "type" => "text", "text" => "hi" } ], "model" => "claude" }
    })
    transport.add_response({
      "type" => "result", "subtype" => "success",
      "duration_ms" => 100, "duration_api_ms" => 80,
      "is_error" => false, "num_turns" => 1,
      "session_id" => "s1", "total_cost_usd" => 0.01,
      "usage" => { "input_tokens" => 10, "output_tokens" => 5 }
    })

    ClaudeAgent.chat(client: client) do |c|
      conversation_ref = c
      c.say("Hello")
    end

    assert conversation_ref.closed?
  end

  # --- Module-level DSL ---

  test "permissions sets default_permissions" do
    ClaudeAgent.permissions do |p|
      p.allow "Read"
      p.deny_all
    end

    assert_instance_of ClaudeAgent::PermissionPolicy, ClaudeAgent.config.default_permissions
  end

  test "hooks sets default_hooks" do
    ClaudeAgent.hooks do |h|
      h.before_tool_use("Bash") { |_, _| {} }
    end

    assert_instance_of ClaudeAgent::HookRegistry, ClaudeAgent.config.default_hooks
  end

  test "register_mcp_server adds to default_mcp_servers" do
    server = ClaudeAgent::MCP::Server.new(name: "calc")
    ClaudeAgent.register_mcp_server(server)

    assert ClaudeAgent.config.default_mcp_servers.key?("calc")
    assert_equal "sdk", ClaudeAgent.config.default_mcp_servers["calc"][:type]
  end
end
