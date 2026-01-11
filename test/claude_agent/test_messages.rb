# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentMessages < ActiveSupport::TestCase
  test "user_message_with_string" do
    msg = ClaudeAgent::UserMessage.new(content: "Hello!")
    assert_equal "Hello!", msg.content
    assert_equal "Hello!", msg.text
    assert_equal :user, msg.type
    assert_nil msg.uuid
    assert_nil msg.parent_tool_use_id
  end

  test "user_message_with_uuid" do
    msg = ClaudeAgent::UserMessage.new(
      content: "Hello!",
      uuid: "abc-123",
      parent_tool_use_id: "tool_456"
    )
    assert_equal "abc-123", msg.uuid
    assert_equal "tool_456", msg.parent_tool_use_id
  end

  test "user_message_with_content_blocks" do
    blocks = [ ClaudeAgent::TextBlock.new(text: "Hello") ]
    msg = ClaudeAgent::UserMessage.new(content: blocks)
    assert_equal blocks, msg.content
    assert_nil msg.text # text returns nil for non-string content
  end

  test "assistant_message" do
    blocks = [
      ClaudeAgent::TextBlock.new(text: "Hello "),
      ClaudeAgent::TextBlock.new(text: "world!")
    ]
    msg = ClaudeAgent::AssistantMessage.new(
      content: blocks,
      model: "claude-sonnet-4-5-20250514"
    )
    assert_equal blocks, msg.content
    assert_equal "claude-sonnet-4-5-20250514", msg.model
    assert_equal "Hello world!", msg.text
    assert_equal :assistant, msg.type
    assert_nil msg.error
  end

  test "assistant_message_with_thinking" do
    blocks = [
      ClaudeAgent::ThinkingBlock.new(thinking: "Let me ", signature: "sig1"),
      ClaudeAgent::ThinkingBlock.new(thinking: "consider...", signature: "sig2"),
      ClaudeAgent::TextBlock.new(text: "The answer is 42")
    ]
    msg = ClaudeAgent::AssistantMessage.new(content: blocks, model: "claude")
    assert_equal "Let me consider...", msg.thinking
    assert_equal "The answer is 42", msg.text
  end

  test "assistant_message_with_tool_use" do
    blocks = [
      ClaudeAgent::TextBlock.new(text: "Let me read that file"),
      ClaudeAgent::ToolUseBlock.new(id: "tool_123", name: "Read", input: { file_path: "/tmp" })
    ]
    msg = ClaudeAgent::AssistantMessage.new(content: blocks, model: "claude")
    assert msg.has_tool_use?
    assert_equal 1, msg.tool_uses.length
    assert_equal "Read", msg.tool_uses.first.name
  end

  test "assistant_message_without_tool_use" do
    blocks = [ ClaudeAgent::TextBlock.new(text: "Just text") ]
    msg = ClaudeAgent::AssistantMessage.new(content: blocks, model: "claude")
    refute msg.has_tool_use?
    assert_empty msg.tool_uses
  end

  test "assistant_message_with_error" do
    msg = ClaudeAgent::AssistantMessage.new(
      content: [],
      model: "claude",
      error: "rate_limit"
    )
    assert_equal "rate_limit", msg.error
  end

  test "system_message" do
    msg = ClaudeAgent::SystemMessage.new(
      subtype: "init",
      data: { version: "2.0.0" }
    )
    assert_equal "init", msg.subtype
    assert_equal({ version: "2.0.0" }, msg.data)
    assert_equal :system, msg.type
  end

  test "result_message_success" do
    msg = ClaudeAgent::ResultMessage.new(
      subtype: "success",
      duration_ms: 1500,
      duration_api_ms: 1200,
      is_error: false,
      num_turns: 3,
      session_id: "session-abc",
      total_cost_usd: 0.05,
      usage: { input_tokens: 100, output_tokens: 50 }
    )
    assert_equal "success", msg.subtype
    assert_equal 1500, msg.duration_ms
    assert_equal 1200, msg.duration_api_ms
    refute msg.error?
    assert msg.success?
    assert_equal 3, msg.num_turns
    assert_equal "session-abc", msg.session_id
    assert_equal 0.05, msg.total_cost_usd
    assert_equal({ input_tokens: 100, output_tokens: 50 }, msg.usage)
    assert_equal :result, msg.type
  end

  test "result_message_error" do
    msg = ClaudeAgent::ResultMessage.new(
      subtype: "error",
      duration_ms: 500,
      duration_api_ms: 400,
      is_error: true,
      num_turns: 1,
      session_id: "session-xyz"
    )
    assert msg.error?
    refute msg.success?
  end

  test "stream_event" do
    event = ClaudeAgent::StreamEvent.new(
      uuid: "evt-123",
      session_id: "session-abc",
      event: { "type" => "content_block_delta", "delta" => { "text" => "Hi" } }
    )
    assert_equal "evt-123", event.uuid
    assert_equal "session-abc", event.session_id
    assert_equal "content_block_delta", event.event_type
    assert_equal :stream_event, event.type
  end

  test "compact_boundary_message" do
    msg = ClaudeAgent::CompactBoundaryMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      compact_metadata: { trigger: "auto", pre_tokens: 50000 }
    )

    assert_equal "msg-123", msg.uuid
    assert_equal "session-abc", msg.session_id
    assert_equal :compact_boundary, msg.type
    assert_equal "auto", msg.trigger
    assert_equal 50000, msg.pre_tokens
  end

  test "compact_boundary_message_with_string_keys" do
    msg = ClaudeAgent::CompactBoundaryMessage.new(
      uuid: "msg-456",
      session_id: "session-xyz",
      compact_metadata: { "trigger" => "manual", "pre_tokens" => 25000 }
    )

    assert_equal "manual", msg.trigger
    assert_equal 25000, msg.pre_tokens
  end

  test "compact_boundary_message_in_types_constant" do
    assert_includes ClaudeAgent::MESSAGE_TYPES, ClaudeAgent::CompactBoundaryMessage
  end

  # --- Session ID on User/Assistant Messages ---

  test "user_message_with_session_id" do
    msg = ClaudeAgent::UserMessage.new(
      content: "Hello!",
      uuid: "abc-123",
      session_id: "session-abc"
    )
    assert_equal "session-abc", msg.session_id
  end

  test "assistant_message_with_session_id" do
    blocks = [ ClaudeAgent::TextBlock.new(text: "Hello") ]
    msg = ClaudeAgent::AssistantMessage.new(
      content: blocks,
      model: "claude",
      uuid: "msg-123",
      session_id: "session-abc"
    )
    assert_equal "session-abc", msg.session_id
  end

  # --- StatusMessage ---

  test "status_message" do
    msg = ClaudeAgent::StatusMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      status: "compacting"
    )
    assert_equal "msg-123", msg.uuid
    assert_equal "session-abc", msg.session_id
    assert_equal "compacting", msg.status
    assert_equal :status, msg.type
  end

  test "status_message_in_types_constant" do
    assert_includes ClaudeAgent::MESSAGE_TYPES, ClaudeAgent::StatusMessage
  end

  # --- ToolProgressMessage ---

  test "tool_progress_message" do
    msg = ClaudeAgent::ToolProgressMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      tool_use_id: "tool-456",
      tool_name: "Bash",
      elapsed_time_seconds: 5.2
    )
    assert_equal "msg-123", msg.uuid
    assert_equal "session-abc", msg.session_id
    assert_equal "tool-456", msg.tool_use_id
    assert_equal "Bash", msg.tool_name
    assert_equal 5.2, msg.elapsed_time_seconds
    assert_nil msg.parent_tool_use_id
    assert_equal :tool_progress, msg.type
  end

  test "tool_progress_message_with_parent" do
    msg = ClaudeAgent::ToolProgressMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      tool_use_id: "tool-456",
      tool_name: "Bash",
      elapsed_time_seconds: 5.2,
      parent_tool_use_id: "parent-789"
    )
    assert_equal "parent-789", msg.parent_tool_use_id
  end

  test "tool_progress_message_in_types_constant" do
    assert_includes ClaudeAgent::MESSAGE_TYPES, ClaudeAgent::ToolProgressMessage
  end

  # --- HookResponseMessage ---

  test "hook_response_message" do
    msg = ClaudeAgent::HookResponseMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      hook_name: "my-hook",
      hook_event: "PreToolUse",
      stdout: "Hook output",
      stderr: "",
      exit_code: 0
    )
    assert_equal "msg-123", msg.uuid
    assert_equal "session-abc", msg.session_id
    assert_equal "my-hook", msg.hook_name
    assert_equal "PreToolUse", msg.hook_event
    assert_equal "Hook output", msg.stdout
    assert_equal "", msg.stderr
    assert_equal 0, msg.exit_code
    assert_equal :hook_response, msg.type
  end

  test "hook_response_message_defaults" do
    msg = ClaudeAgent::HookResponseMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      hook_name: "my-hook",
      hook_event: "PreToolUse"
    )
    assert_equal "", msg.stdout
    assert_equal "", msg.stderr
    assert_nil msg.exit_code
  end

  test "hook_response_message_in_types_constant" do
    assert_includes ClaudeAgent::MESSAGE_TYPES, ClaudeAgent::HookResponseMessage
  end

  # --- AuthStatusMessage ---

  test "auth_status_message" do
    msg = ClaudeAgent::AuthStatusMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      is_authenticating: true,
      output: [ "Waiting for browser..." ],
      error: nil
    )
    assert_equal "msg-123", msg.uuid
    assert_equal "session-abc", msg.session_id
    assert_equal true, msg.is_authenticating
    assert_equal [ "Waiting for browser..." ], msg.output
    assert_nil msg.error
    assert_equal :auth_status, msg.type
  end

  test "auth_status_message_with_error" do
    msg = ClaudeAgent::AuthStatusMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      is_authenticating: false,
      error: "Authentication failed"
    )
    assert_equal "Authentication failed", msg.error
    refute msg.is_authenticating
    assert_equal [], msg.output
  end

  test "auth_status_message_in_types_constant" do
    assert_includes ClaudeAgent::MESSAGE_TYPES, ClaudeAgent::AuthStatusMessage
  end
end
