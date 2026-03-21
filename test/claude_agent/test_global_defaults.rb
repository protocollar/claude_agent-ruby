# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentGlobalDefaults < ActiveSupport::TestCase
  setup do
    @original_config = ClaudeAgent.config
    ClaudeAgent.reset_config!
  end

  teardown do
    ClaudeAgent.instance_variable_set(:@config, @original_config)
  end

  # --- PermissionPolicy flows through to Options ---

  test "PermissionPolicy in Options#validate! compiles to lambda" do
    policy = ClaudeAgent::PermissionPolicy.new do |p|
      p.allow "Read"
      p.deny_all
    end

    options = ClaudeAgent::Options.new(can_use_tool: policy)
    assert options.can_use_tool.respond_to?(:call)

    result = options.can_use_tool.call("Read", {}, nil)
    assert_equal "allow", result.behavior
  end

  test "HookRegistry in Options stays as registry" do
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.before_tool_use("Bash") { |_, _| { continue_: true } }
    end

    options = ClaudeAgent::Options.new(hooks: registry)
    assert options.hooks.is_a?(ClaudeAgent::HookRegistry)
    assert options.hooks.key?("PreToolUse")
  end

  # --- Symbol permission modes in Conversation ---

  test "on_permission :accept_edits sets permission mode" do
    conversation = ClaudeAgent::Conversation.new(on_permission: :accept_edits)
    # The conversation was created without error — the permission mode was set
    assert_instance_of ClaudeAgent::Conversation, conversation
  end

  test "on_permission :dont_ask sets permission mode" do
    conversation = ClaudeAgent::Conversation.new(on_permission: :dont_ask)
    assert_instance_of ClaudeAgent::Conversation, conversation
  end

  test "on_permission with PermissionPolicy compiles" do
    policy = ClaudeAgent::PermissionPolicy.new do |p|
      p.allow "Read"
      p.deny_all
    end

    conversation = ClaudeAgent::Conversation.new(on_permission: policy)
    assert_instance_of ClaudeAgent::Conversation, conversation
  end

  test "HookRegistry in Conversation hooks option compiles" do
    registry = ClaudeAgent::HookRegistry.new do |h|
      h.before_tool_use("Bash") { |_, _| { continue_: true } }
    end

    conversation = ClaudeAgent::Conversation.new(hooks: registry)
    assert_instance_of ClaudeAgent::Conversation, conversation
  end

  # --- Global defaults flow into ask ---

  test "global permissions flow into ask options" do
    ClaudeAgent.permissions do |p|
      p.allow "Read"
      p.deny_all
    end

    options_captured = nil
    ClaudeAgent.stubs(:query_turn).with do |prompt:, options:, events:|
      options_captured = options
      true
    end.returns(ClaudeAgent::TurnResult.new)

    ClaudeAgent.ask("test")

    assert_not_nil options_captured.can_use_tool
    result = options_captured.can_use_tool.call("Read", {}, nil)
    assert_equal "allow", result.behavior
  end

  test "global hooks flow into ask options" do
    ClaudeAgent.hooks do |h|
      h.before_tool_use("Bash") { |_, _| { continue_: true } }
    end

    options_captured = nil
    ClaudeAgent.stubs(:query_turn).with do |prompt:, options:, events:|
      options_captured = options
      true
    end.returns(ClaudeAgent::TurnResult.new)

    ClaudeAgent.ask("test")

    assert options_captured.has_hooks?
    assert options_captured.hooks.key?("PreToolUse")
  end

  test "global MCP servers flow into ask options" do
    server = ClaudeAgent::MCP::Server.new(name: "calc")
    ClaudeAgent.register_mcp_server(server)

    options_captured = nil
    ClaudeAgent.stubs(:query_turn).with do |prompt:, options:, events:|
      options_captured = options
      true
    end.returns(ClaudeAgent::TurnResult.new)

    ClaudeAgent.ask("test")

    assert options_captured.mcp_servers.key?("calc")
  end

  # --- EventHandler.define ---

  test "EventHandler.define with block DSL" do
    texts = []
    handler = ClaudeAgent::EventHandler.define do
      on_text { |t| texts << t }
    end

    assert handler.has_handlers?

    msg = ClaudeAgent::AssistantMessage.new(
      content: [ ClaudeAgent::TextBlock.new(text: "Hello!") ],
      model: "claude"
    )
    handler.handle(msg)

    assert_equal [ "Hello!" ], texts
  end

  # --- MCP block DSL ---

  test "Server block DSL creates tools" do
    server = ClaudeAgent::MCP::Server.new(name: "calc") do |s|
      s.tool("add", "Add numbers", { a: :number, b: :number }) { |args| (args[:a] + args[:b]).to_s }
    end

    assert_equal 1, server.tools.size
    assert server.tools["add"]
  end

  test "MCP Tool symbol schema shortcuts" do
    tool = ClaudeAgent::MCP::Tool.new(
      name: "test",
      description: "Test",
      schema: { name: :string, count: :integer, ratio: :float, active: :boolean }
    ) { |_| "ok" }

    props = tool.schema[:properties]
    assert_equal "string", props[:name][:type]
    assert_equal "integer", props[:count][:type]
    assert_equal "number", props[:ratio][:type]
    assert_equal "boolean", props[:active][:type]
  end
end
