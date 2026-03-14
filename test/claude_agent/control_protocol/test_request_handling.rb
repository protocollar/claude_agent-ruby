# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentControlProtocolRequestHandling < ActiveSupport::TestCase
  setup do
    @transport = MockTransport.new
    @options = ClaudeAgent::Options.new
    @protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: @options)
  end

  # --- normalize_hook_response ---

  test "normalize hook response basic" do
    result = {
      continue_: true,
      suppress_output: false,
      decision: "allow"
    }

    normalized = @protocol.send(:normalize_hook_response, result)

    assert_equal true, normalized["continue"]
    assert_equal false, normalized["suppressOutput"]
    assert_equal "allow", normalized["decision"]
  end

  test "normalize hook response with async" do
    result = {
      async_: true,
      stop_reason: "user_requested"
    }

    normalized = @protocol.send(:normalize_hook_response, result)

    assert_equal true, normalized["async"]
    assert_equal "user_requested", normalized["stopReason"]
  end

  test "normalize hook response with object responding to to_h" do
    response_obj = Data.define(:continue_, :decision).new(continue_: true, decision: "allow")
    normalized = @protocol.send(:normalize_hook_response, response_obj)

    assert_equal true, normalized["continue"]
    assert_equal "allow", normalized["decision"]
  end

  # --- handle_can_use_tool ---

  test "handle can use tool default allow" do
    request = { "tool_name" => "Read", "input" => { "file_path" => "/tmp/test" } }

    result = @protocol.send(:handle_can_use_tool, request)

    assert_equal "allow", result[:behavior]
  end

  test "handle can use tool with callback allow" do
    options = ClaudeAgent::Options.new(
      can_use_tool: ->(name, input, context) {
        ClaudeAgent::PermissionResultAllow.new(updated_input: input.merge(modified: true))
      }
    )
    protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: options)

    request = { "tool_name" => "Read", "input" => { "file_path" => "/tmp" } }
    result = protocol.send(:handle_can_use_tool, request)

    assert_equal "allow", result[:behavior]
    assert result[:updatedInput][:modified]
  end

  test "handle can use tool with callback deny" do
    options = ClaudeAgent::Options.new(
      can_use_tool: ->(name, input, context) {
        ClaudeAgent::PermissionResultDeny.new(message: "Not allowed", interrupt: true)
      }
    )
    protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: options)

    request = { "tool_name" => "Bash", "input" => { "command" => "rm -rf /" } }
    result = protocol.send(:handle_can_use_tool, request)

    assert_equal "deny", result[:behavior]
    assert_equal "Not allowed", result[:message]
    assert result[:interrupt]
  end

  # --- handle_hook_callback ---

  test "handle hook callback" do
    callback_called = false
    callback_input = nil

    options = ClaudeAgent::Options.new(
      hooks: {
        "PreToolUse" => [
          ClaudeAgent::HookMatcher.new(
            matcher: "Read",
            callbacks: [ ->(input, context) {
              callback_called = true
              callback_input = input
              { continue_: true }
            } ],
            timeout: nil
          )
        ]
      }
    )
    protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: options)

    # Build hooks config to register callbacks
    protocol.send(:build_hooks_config)

    request = {
      "callback_id" => "hook_PreToolUse_0_0",
      "input" => { "tool_name" => "Read", "tool_input" => {} },
      "tool_use_id" => "tool_123"
    }
    result = protocol.send(:handle_hook_callback, request)

    assert callback_called
    assert_equal({ tool_name: "Read", tool_input: {} }, callback_input)
    assert_equal true, result["continue"]
  end

  # --- can_use_tool with PermissionResultAllow ---

  test "handle can use tool with PermissionResultAllow" do
    options = ClaudeAgent::Options.new(
      can_use_tool: ->(name, input, context) {
        ClaudeAgent::PermissionResultAllow.new
      }
    )
    protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: options)

    request = { "tool_name" => "Read", "input" => { "file_path" => "/tmp" } }
    result = protocol.send(:handle_can_use_tool, request)

    assert_equal "allow", result[:behavior]
    # Falls back to original input when updatedInput not provided (Python SDK parity)
    assert_equal({ file_path: "/tmp" }, result[:updatedInput])
  end

  test "handle can use tool with PermissionResultAllow with updated_input" do
    options = ClaudeAgent::Options.new(
      can_use_tool: ->(name, input, context) {
        ClaudeAgent::PermissionResultAllow.new(updated_input: { "safe" => true })
      }
    )
    protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: options)

    request = { "tool_name" => "Read", "input" => { "file_path" => "/tmp" } }
    result = protocol.send(:handle_can_use_tool, request)

    assert_equal "allow", result[:behavior]
    assert_equal({ "safe" => true }, result[:updatedInput])
  end

  test "handle can use tool with PermissionResultAllow with updated_permissions" do
    options = ClaudeAgent::Options.new(
      can_use_tool: ->(name, input, context) {
        ClaudeAgent::PermissionResultAllow.new(
          updated_permissions: [
            ClaudeAgent::PermissionUpdate.new(type: "addRules", rules: [ { tool_name: "Read" } ], behavior: "allow")
          ]
        )
      }
    )
    protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: options)

    request = { "tool_name" => "Read", "input" => {} }
    result = protocol.send(:handle_can_use_tool, request)

    assert_equal "allow", result[:behavior]
    assert result[:updatedPermissions].is_a?(Array)
    assert_equal 1, result[:updatedPermissions].length
  end

  # --- can_use_tool with PermissionResultDeny ---

  test "handle can use tool with PermissionResultDeny" do
    options = ClaudeAgent::Options.new(
      can_use_tool: ->(name, input, context) {
        ClaudeAgent::PermissionResultDeny.new(message: "Blocked", interrupt: true)
      }
    )
    protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: options)

    request = { "tool_name" => "Bash", "input" => { "command" => "rm -rf /" } }
    result = protocol.send(:handle_can_use_tool, request)

    assert_equal "deny", result[:behavior]
    assert_equal "Blocked", result[:message]
    assert_equal true, result[:interrupt]
  end

  test "handle can use tool with PermissionResultDeny defaults" do
    options = ClaudeAgent::Options.new(
      can_use_tool: ->(name, input, context) {
        ClaudeAgent::PermissionResultDeny.new
      }
    )
    protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: options)

    request = { "tool_name" => "Write", "input" => {} }
    result = protocol.send(:handle_can_use_tool, request)

    assert_equal "deny", result[:behavior]
    assert_equal "", result[:message]
    assert_equal false, result[:interrupt]
  end

  # --- Permission Queue Mode ---

  test "handle can use tool with permission queue" do
    queue = ClaudeAgent::PermissionQueue.new
    protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: @options)
    protocol.permission_queue = queue

    request = { "tool_name" => "Bash", "input" => { "command" => "ls" }, "tool_use_id" => "t1" }

    # Resolve from another thread
    Thread.new do
      sleep 0.05
      perm_request = queue.pop(timeout: 2)
      perm_request.allow!
    end

    result = protocol.send(:handle_can_use_tool, request)

    assert_equal "allow", result[:behavior]
    assert_equal({ command: "ls" }, result[:updatedInput])
  end

  test "handle can use tool with permission queue deny" do
    queue = ClaudeAgent::PermissionQueue.new
    protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: @options)
    protocol.permission_queue = queue

    request = { "tool_name" => "Bash", "input" => { "command" => "rm -rf /" } }

    Thread.new do
      sleep 0.05
      perm_request = queue.pop(timeout: 2)
      perm_request.deny!(message: "Too dangerous")
    end

    result = protocol.send(:handle_can_use_tool, request)

    assert_equal "deny", result[:behavior]
    assert_equal "Too dangerous", result[:message]
  end

  test "handle can use tool callback takes priority over queue" do
    queue = ClaudeAgent::PermissionQueue.new
    options = ClaudeAgent::Options.new(
      can_use_tool: ->(name, input, context) {
        ClaudeAgent::PermissionResultAllow.new
      }
    )
    protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: options)
    protocol.permission_queue = queue

    request = { "tool_name" => "Read", "input" => {} }
    result = protocol.send(:handle_can_use_tool, request)

    assert_equal "allow", result[:behavior]
    assert queue.empty?, "Queue should not be used when callback is set"
  end

  test "handle can use tool hybrid defer mode" do
    queue = ClaudeAgent::PermissionQueue.new
    options = ClaudeAgent::Options.new(
      can_use_tool: ->(name, input, context) {
        if name == "Read"
          ClaudeAgent::PermissionResultAllow.new
        else
          context.request.defer!
        end
      }
    )
    protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: options)
    protocol.permission_queue = queue

    # Read should be allowed synchronously
    read_result = protocol.send(:handle_can_use_tool, { "tool_name" => "Read", "input" => {} })
    assert_equal "allow", read_result[:behavior]
    assert queue.empty?

    # Bash should be deferred to the queue
    Thread.new do
      sleep 0.05
      perm_request = queue.pop(timeout: 2)
      perm_request.allow!
    end

    bash_result = protocol.send(:handle_can_use_tool, { "tool_name" => "Bash", "input" => { "command" => "ls" } })
    assert_equal "allow", bash_result[:behavior]
  end

  test "handle can use tool provides context on queued request" do
    queue = ClaudeAgent::PermissionQueue.new
    protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: @options)
    protocol.permission_queue = queue

    request = {
      "tool_name" => "Write",
      "input" => { "file_path" => "/tmp/test.txt" },
      "tool_use_id" => "t-42",
      "blocked_path" => "/tmp/test.txt",
      "decision_reason" => "Path needs approval"
    }

    captured_request = nil
    Thread.new do
      sleep 0.05
      captured_request = queue.pop(timeout: 2)
      captured_request.allow!
    end

    protocol.send(:handle_can_use_tool, request)

    assert_not_nil captured_request
    assert_equal "Write", captured_request.tool_name
    assert_equal({ file_path: "/tmp/test.txt" }, captured_request.input)
    assert_equal "t-42", captured_request.context.tool_use_id
    assert_equal "/tmp/test.txt", captured_request.context.blocked_path
    assert_equal "Path needs approval", captured_request.context.decision_reason
  end

  test "handle can use tool default allow without queue or callback" do
    protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: @options)
    # No queue, no callback

    request = { "tool_name" => "Read", "input" => {} }
    result = protocol.send(:handle_can_use_tool, request)

    assert_equal "allow", result[:behavior]
  end

  # --- Elicitation Handling ---

  test "handle elicitation with callback" do
    callback_request = nil
    options = ClaudeAgent::Options.new(
      on_elicitation: ->(request, signal:) {
        callback_request = request
        { action: "approve", content: { token: "abc" } }
      }
    )
    protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: options)

    request = {
      "mcp_server_name" => "my-server",
      "message" => "Auth needed",
      "mode" => "modal",
      "url" => "https://example.com",
      "elicitation_id" => "elic-123",
      "requested_schema" => { "type" => "object" }
    }

    result = protocol.send(:handle_elicitation, request)

    assert_equal "approve", result[:action]
    assert_equal({ token: "abc" }, result[:content])
    assert_equal "my-server", callback_request[:server_name]
    assert_equal "Auth needed", callback_request[:message]
    assert_equal "modal", callback_request[:mode]
    assert_equal "https://example.com", callback_request[:url]
    assert_equal "elic-123", callback_request[:elicitation_id]
  end

  test "handle elicitation without callback defaults to decline" do
    request = {
      "mcp_server_name" => "my-server",
      "message" => "Auth needed"
    }

    result = @protocol.send(:handle_elicitation, request)

    assert_equal "decline", result[:action]
  end

  test "handle elicitation with nil callback result defaults to decline" do
    options = ClaudeAgent::Options.new(
      on_elicitation: ->(request, signal:) { nil }
    )
    protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: options)

    request = {
      "mcp_server_name" => "my-server",
      "message" => "Auth needed"
    }

    result = protocol.send(:handle_elicitation, request)

    assert_equal "decline", result[:action]
  end

  test "handle elicitation routed via handle_control_request" do
    options = ClaudeAgent::Options.new(
      on_elicitation: ->(request, signal:) { { action: "approve" } }
    )
    protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: options)
    @transport.connect

    raw = {
      "type" => "control_request",
      "request_id" => "req-elic-1",
      "request" => {
        "subtype" => "elicitation",
        "mcp_server_name" => "my-server",
        "message" => "Auth needed"
      }
    }

    protocol.send(:handle_control_request, raw)

    response = @transport.written_messages.find { |m| m["type"] == "control_response" }
    assert_not_nil response
    assert_equal "success", response["response"]["subtype"]
    assert_equal "req-elic-1", response["response"]["request_id"]
    assert_equal "approve", response["response"]["response"]["action"]
  end
end
