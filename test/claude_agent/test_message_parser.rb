# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentMessageParser < ActiveSupport::TestCase
  setup do
    @parser = ClaudeAgent::MessageParser.new
  end

  test "parse_user_message_string_content" do
    raw = {
      "type" => "user",
      "uuid" => "msg-123",
      "message" => { "content" => "Hello!" }
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::UserMessage, msg
    assert_equal "Hello!", msg.content
    assert_equal "msg-123", msg.uuid
  end

  test "parse_user_message_with_tool_result" do
    raw = {
      "type" => "user",
      "message" => {
        "content" => [
          { "type" => "tool_result", "tool_use_id" => "tool_123", "content" => "result" }
        ]
      }
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::UserMessage, msg
    assert_instance_of Array, msg.content
    assert_instance_of ClaudeAgent::ToolResultBlock, msg.content.first
    assert_equal "tool_123", msg.content.first.tool_use_id
  end

  test "parse_assistant_message" do
    raw = {
      "type" => "assistant",
      "message" => {
        "model" => "claude-sonnet-4-5-20250514",
        "content" => [
          { "type" => "text", "text" => "Hello, world!" }
        ]
      }
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::AssistantMessage, msg
    assert_equal "claude-sonnet-4-5-20250514", msg.model
    assert_equal 1, msg.content.length
    assert_instance_of ClaudeAgent::TextBlock, msg.content.first
    assert_equal "Hello, world!", msg.text
  end

  test "parse_assistant_message_with_thinking" do
    raw = {
      "type" => "assistant",
      "message" => {
        "model" => "claude",
        "content" => [
          { "type" => "thinking", "thinking" => "Analyzing...", "signature" => "sig123" },
          { "type" => "text", "text" => "The answer is 42" }
        ]
      }
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::AssistantMessage, msg
    assert_equal 2, msg.content.length
    assert_instance_of ClaudeAgent::ThinkingBlock, msg.content.first
    assert_equal "Analyzing...", msg.thinking
    assert_equal "The answer is 42", msg.text
  end

  test "parse_assistant_message_with_tool_use" do
    raw = {
      "type" => "assistant",
      "message" => {
        "model" => "claude",
        "content" => [
          { "type" => "text", "text" => "Let me read that file" },
          {
            "type" => "tool_use",
            "id" => "tool_abc",
            "name" => "Read",
            "input" => { "file_path" => "/tmp/test.txt" }
          }
        ]
      }
    }
    msg = @parser.parse(raw)

    assert msg.has_tool_use?
    tool_use = msg.tool_uses.first
    assert_equal "tool_abc", tool_use.id
    assert_equal "Read", tool_use.name
    assert_equal({ "file_path" => "/tmp/test.txt" }, tool_use.input)
  end

  test "parse_assistant_message_with_error" do
    raw = {
      "type" => "assistant",
      "error" => "rate_limit",
      "message" => {
        "model" => "claude",
        "content" => []
      }
    }
    msg = @parser.parse(raw)

    assert_equal "rate_limit", msg.error
  end

  test "parse_system_message" do
    raw = {
      "type" => "system",
      "subtype" => "init",
      "data" => { "version" => "2.1.0" }
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::SystemMessage, msg
    assert_equal "init", msg.subtype
    assert_equal({ "version" => "2.1.0" }, msg.data)
  end

  test "parse_result_message" do
    raw = {
      "type" => "result",
      "subtype" => "success",
      "duration_ms" => 1500,
      "duration_api_ms" => 1200,
      "is_error" => false,
      "num_turns" => 3,
      "session_id" => "sess-123",
      "total_cost_usd" => 0.05,
      "usage" => { "input_tokens" => 100, "output_tokens" => 50 }
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::ResultMessage, msg
    assert_equal "success", msg.subtype
    assert_equal 1500, msg.duration_ms
    assert_equal 1200, msg.duration_api_ms
    refute msg.error?
    assert_equal 3, msg.num_turns
    assert_equal "sess-123", msg.session_id
    assert_equal 0.05, msg.total_cost_usd
    assert_equal({ "input_tokens" => 100, "output_tokens" => 50 }, msg.usage)
  end

  test "parse_result_message_camel_case" do
    # Test that parser handles camelCase field names from CLI
    raw = {
      "type" => "result",
      "subtype" => "success",
      "durationMs" => 1500,
      "durationApiMs" => 1200,
      "isError" => false,
      "numTurns" => 3,
      "sessionId" => "sess-123",
      "totalCostUsd" => 0.05
    }
    msg = @parser.parse(raw)

    assert_equal 1500, msg.duration_ms
    assert_equal 1200, msg.duration_api_ms
    refute msg.error?
    assert_equal 3, msg.num_turns
    assert_equal "sess-123", msg.session_id
    assert_equal 0.05, msg.total_cost_usd
  end

  test "parse_stream_event" do
    raw = {
      "type" => "stream_event",
      "uuid" => "evt-123",
      "session_id" => "sess-abc",
      "event" => {
        "type" => "content_block_delta",
        "delta" => { "type" => "text_delta", "text" => "Hello" }
      }
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::StreamEvent, msg
    assert_equal "evt-123", msg.uuid
    assert_equal "sess-abc", msg.session_id
    assert_equal "content_block_delta", msg.event_type
  end

  test "parse_unknown_type_raises_error" do
    raw = { "type" => "unknown_type" }

    error = assert_raises(ClaudeAgent::MessageParseError) do
      @parser.parse(raw)
    end
    assert_match(/Unknown message type/, error.message)
  end

  test "parse_server_tool_use_block" do
    raw = {
      "type" => "assistant",
      "message" => {
        "model" => "claude",
        "content" => [
          {
            "type" => "server_tool_use",
            "id" => "srv_tool_123",
            "name" => "fetch",
            "input" => { "url" => "https://example.com" },
            "server_name" => "web_server"
          }
        ]
      }
    }
    msg = @parser.parse(raw)

    block = msg.content.first
    assert_instance_of ClaudeAgent::ServerToolUseBlock, block
    assert_equal "srv_tool_123", block.id
    assert_equal "fetch", block.name
    assert_equal "web_server", block.server_name
  end

  test "parse_server_tool_result_block" do
    raw = {
      "type" => "user",
      "message" => {
        "content" => [
          {
            "type" => "server_tool_result",
            "tool_use_id" => "srv_tool_123",
            "content" => "response data",
            "server_name" => "web_server"
          }
        ]
      }
    }
    msg = @parser.parse(raw)

    block = msg.content.first
    assert_instance_of ClaudeAgent::ServerToolResultBlock, block
    assert_equal "srv_tool_123", block.tool_use_id
    assert_equal "web_server", block.server_name
    assert_equal "response data", block.content
  end

  test "parse_image_content_block" do
    raw = {
      "type" => "assistant",
      "message" => {
        "model" => "claude",
        "content" => [
          {
            "type" => "image",
            "source" => {
              "type" => "base64",
              "media_type" => "image/png",
              "data" => "iVBORw0KGgo..."
            }
          }
        ]
      }
    }
    msg = @parser.parse(raw)

    block = msg.content.first
    assert_instance_of ClaudeAgent::ImageContentBlock, block
    assert_equal "base64", block.source_type
    assert_equal "image/png", block.media_type
    assert_equal "iVBORw0KGgo...", block.data
  end

  test "parse_compact_boundary_message" do
    raw = {
      "type" => "system",
      "subtype" => "compact_boundary",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "compact_metadata" => {
        "trigger" => "auto",
        "pre_tokens" => 50000
      }
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::CompactBoundaryMessage, msg
    assert_equal "msg-123", msg.uuid
    assert_equal "sess-abc", msg.session_id
    assert_equal "auto", msg.trigger
    assert_equal 50000, msg.pre_tokens
    assert_equal :compact_boundary, msg.type
  end

  test "parse_compact_boundary_message_camel_case" do
    raw = {
      "type" => "system",
      "subtype" => "compact_boundary",
      "uuid" => "msg-456",
      "sessionId" => "sess-xyz",
      "compactMetadata" => {
        "trigger" => "manual",
        "pre_tokens" => 25000
      }
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::CompactBoundaryMessage, msg
    assert_equal "sess-xyz", msg.session_id
    assert_equal "manual", msg.trigger
    assert_equal 25000, msg.pre_tokens
  end

  # --- Session ID parsing ---

  test "parse_user_message_with_session_id" do
    raw = {
      "type" => "user",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "message" => { "content" => "Hello!" }
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::UserMessage, msg
    assert_equal "sess-abc", msg.session_id
  end

  test "parse_user_message_with_session_id_camel_case" do
    raw = {
      "type" => "user",
      "uuid" => "msg-123",
      "sessionId" => "sess-abc",
      "message" => { "content" => "Hello!" }
    }
    msg = @parser.parse(raw)

    assert_equal "sess-abc", msg.session_id
  end

  test "parse_assistant_message_with_session_id" do
    raw = {
      "type" => "assistant",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "message" => {
        "model" => "claude",
        "content" => [ { "type" => "text", "text" => "Hello!" } ]
      }
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::AssistantMessage, msg
    assert_equal "sess-abc", msg.session_id
  end

  # --- StatusMessage parsing ---

  test "parse_status_message" do
    raw = {
      "type" => "system",
      "subtype" => "status",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "status" => "compacting"
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::StatusMessage, msg
    assert_equal "msg-123", msg.uuid
    assert_equal "sess-abc", msg.session_id
    assert_equal "compacting", msg.status
    assert_equal :status, msg.type
  end

  test "parse_status_message_camel_case" do
    raw = {
      "type" => "system",
      "subtype" => "status",
      "uuid" => "msg-456",
      "sessionId" => "sess-xyz",
      "status" => "processing"
    }
    msg = @parser.parse(raw)

    assert_equal "sess-xyz", msg.session_id
    assert_equal "processing", msg.status
  end

  # --- ToolProgressMessage parsing ---

  test "parse_tool_progress_message" do
    raw = {
      "type" => "tool_progress",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "tool_use_id" => "tool-456",
      "tool_name" => "Bash",
      "elapsed_time_seconds" => 5.2
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::ToolProgressMessage, msg
    assert_equal "msg-123", msg.uuid
    assert_equal "sess-abc", msg.session_id
    assert_equal "tool-456", msg.tool_use_id
    assert_equal "Bash", msg.tool_name
    assert_equal 5.2, msg.elapsed_time_seconds
    assert_nil msg.parent_tool_use_id
    assert_equal :tool_progress, msg.type
  end

  test "parse_tool_progress_message_camel_case" do
    raw = {
      "type" => "tool_progress",
      "uuid" => "msg-123",
      "sessionId" => "sess-xyz",
      "toolUseId" => "tool-456",
      "toolName" => "Write",
      "elapsedTimeSeconds" => 10.5,
      "parentToolUseId" => "parent-789"
    }
    msg = @parser.parse(raw)

    assert_equal "sess-xyz", msg.session_id
    assert_equal "tool-456", msg.tool_use_id
    assert_equal "Write", msg.tool_name
    assert_equal 10.5, msg.elapsed_time_seconds
    assert_equal "parent-789", msg.parent_tool_use_id
  end

  # --- HookResponseMessage parsing ---

  test "parse_hook_response_message" do
    raw = {
      "type" => "system",
      "subtype" => "hook_response",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "hook_name" => "my-hook",
      "hook_event" => "PreToolUse",
      "stdout" => "Hook output",
      "stderr" => "Warning message",
      "exit_code" => 0
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::HookResponseMessage, msg
    assert_equal "msg-123", msg.uuid
    assert_equal "sess-abc", msg.session_id
    assert_equal "my-hook", msg.hook_name
    assert_equal "PreToolUse", msg.hook_event
    assert_equal "Hook output", msg.stdout
    assert_equal "Warning message", msg.stderr
    assert_equal 0, msg.exit_code
    assert_equal :hook_response, msg.type
  end

  test "parse_hook_response_message_camel_case" do
    raw = {
      "type" => "system",
      "subtype" => "hook_response",
      "uuid" => "msg-456",
      "sessionId" => "sess-xyz",
      "hookName" => "format-hook",
      "hookEvent" => "PostToolUse",
      "stdout" => "Formatted",
      "stderr" => "",
      "exitCode" => 1
    }
    msg = @parser.parse(raw)

    assert_equal "sess-xyz", msg.session_id
    assert_equal "format-hook", msg.hook_name
    assert_equal "PostToolUse", msg.hook_event
    assert_equal 1, msg.exit_code
  end

  # --- AuthStatusMessage parsing ---

  test "parse_auth_status_message" do
    raw = {
      "type" => "auth_status",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "is_authenticating" => true,
      "output" => [ "Waiting for browser..." ]
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::AuthStatusMessage, msg
    assert_equal "msg-123", msg.uuid
    assert_equal "sess-abc", msg.session_id
    assert_equal true, msg.is_authenticating
    assert_equal [ "Waiting for browser..." ], msg.output
    assert_nil msg.error
    assert_equal :auth_status, msg.type
  end

  test "parse_auth_status_message_camel_case" do
    raw = {
      "type" => "auth_status",
      "uuid" => "msg-456",
      "sessionId" => "sess-xyz",
      "isAuthenticating" => false,
      "output" => [],
      "error" => "Auth failed"
    }
    msg = @parser.parse(raw)

    assert_equal "sess-xyz", msg.session_id
    refute msg.is_authenticating
    assert_equal [], msg.output
    assert_equal "Auth failed", msg.error
  end

  # --- TaskNotificationMessage parsing ---

  test "parse_task_notification_message" do
    raw = {
      "type" => "system",
      "subtype" => "task_notification",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "task_id" => "task-456",
      "status" => "completed",
      "output_file" => "/path/to/output.txt",
      "summary" => "Task completed successfully"
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::TaskNotificationMessage, msg
    assert_equal "msg-123", msg.uuid
    assert_equal "sess-abc", msg.session_id
    assert_equal "task-456", msg.task_id
    assert_equal "completed", msg.status
    assert_equal "/path/to/output.txt", msg.output_file
    assert_equal "Task completed successfully", msg.summary
    assert_equal :task_notification, msg.type
  end

  test "parse_task_notification_message_camel_case" do
    raw = {
      "type" => "system",
      "subtype" => "task_notification",
      "uuid" => "msg-456",
      "sessionId" => "sess-xyz",
      "taskId" => "task-789",
      "status" => "failed",
      "outputFile" => "/path/to/error.log",
      "summary" => "Task failed"
    }
    msg = @parser.parse(raw)

    assert_equal "sess-xyz", msg.session_id
    assert_equal "task-789", msg.task_id
    assert_equal "failed", msg.status
    assert_equal "/path/to/error.log", msg.output_file
    assert_equal "Task failed", msg.summary
  end

  test "parse_task_notification_message_status_helpers" do
    raw = {
      "type" => "system",
      "subtype" => "task_notification",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "task_id" => "task-456",
      "status" => "stopped",
      "output_file" => "/path/to/output.txt",
      "summary" => "Task stopped by user"
    }
    msg = @parser.parse(raw)

    refute msg.completed?
    refute msg.failed?
    assert msg.stopped?
  end
end
