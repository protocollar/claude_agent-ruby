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
    assert_equal({ file_path: "/tmp/test.txt" }, tool_use.input)
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
    assert_equal({ version: "2.1.0" }, msg.data)
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
    assert_equal({ input_tokens: 100, output_tokens: 50 }, msg.usage)
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

  test "parse_result_message_with_stop_reason" do
    raw = {
      "type" => "result",
      "subtype" => "success",
      "duration_ms" => 1500,
      "duration_api_ms" => 1200,
      "is_error" => false,
      "num_turns" => 3,
      "session_id" => "sess-123",
      "stop_reason" => "end_turn"
    }
    msg = @parser.parse(raw)

    assert_equal "end_turn", msg.stop_reason
  end

  test "parse_result_message_with_stop_reason_camel_case" do
    raw = {
      "type" => "result",
      "subtype" => "success",
      "durationMs" => 1500,
      "durationApiMs" => 1200,
      "isError" => false,
      "numTurns" => 3,
      "sessionId" => "sess-123",
      "stopReason" => "max_tokens"
    }
    msg = @parser.parse(raw)

    assert_equal "max_tokens", msg.stop_reason
  end

  test "parse_result_message_stop_reason_default_nil" do
    raw = {
      "type" => "result",
      "subtype" => "success",
      "duration_ms" => 1500,
      "duration_api_ms" => 1200,
      "is_error" => false,
      "num_turns" => 3,
      "session_id" => "sess-123"
    }
    msg = @parser.parse(raw)

    assert_nil msg.stop_reason
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

  test "parse_unknown_type_returns_generic_message" do
    raw = { "type" => "fancy_new", "data" => "hello", "extra" => 42 }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::GenericMessage, msg
    assert_equal :fancy_new, msg.type
    assert_equal "fancy_new", msg.message_type
    assert_equal "hello", msg[:data]
    assert_equal "hello", msg.data
    assert_equal 42, msg[:extra]
    assert_equal msg.raw, msg.to_h
  end

  test "parse_unknown_content_block_returns_generic_block" do
    raw = {
      "type" => "assistant",
      "message" => {
        "model" => "claude",
        "content" => [
          { "type" => "citation", "text" => "ref", "url" => "https://example.com" }
        ]
      }
    }
    msg = @parser.parse(raw)

    block = msg.content.first
    assert_instance_of ClaudeAgent::GenericBlock, block
    assert_equal :citation, block.type
    assert_equal "citation", block.block_type
    assert_equal "ref", block[:text]
    assert_equal "ref", block.text
    assert_equal "https://example.com", block[:url]
    assert_equal block.raw, block.to_h
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

  test "parse_status_message_with_permission_mode" do
    raw = {
      "type" => "system",
      "subtype" => "status",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "status" => "compacting",
      "permission_mode" => "acceptEdits"
    }
    msg = @parser.parse(raw)

    assert_equal "acceptEdits", msg.permission_mode
  end

  test "parse_status_message_with_permission_mode_camel_case" do
    raw = {
      "type" => "system",
      "subtype" => "status",
      "uuid" => "msg-123",
      "sessionId" => "sess-abc",
      "status" => "compacting",
      "permissionMode" => "bypassPermissions"
    }
    msg = @parser.parse(raw)

    assert_equal "bypassPermissions", msg.permission_mode
  end

  test "parse_status_message_permission_mode_default_nil" do
    raw = {
      "type" => "system",
      "subtype" => "status",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "status" => "compacting"
    }
    msg = @parser.parse(raw)

    assert_nil msg.permission_mode
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

  test "parse_tool_progress_message_with_task_id" do
    raw = {
      "type" => "tool_progress",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "tool_use_id" => "tool-456",
      "tool_name" => "Bash",
      "elapsed_time_seconds" => 5.2,
      "task_id" => "task-789"
    }
    msg = @parser.parse(raw)

    assert_equal "task-789", msg.task_id
  end

  test "parse_tool_progress_message_task_id_default_nil" do
    raw = {
      "type" => "tool_progress",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "tool_use_id" => "tool-456",
      "tool_name" => "Bash",
      "elapsed_time_seconds" => 5.2
    }
    msg = @parser.parse(raw)

    assert_nil msg.task_id
  end

  # --- HookResponseMessage parsing ---

  test "parse_hook_response_message" do
    raw = {
      "type" => "system",
      "subtype" => "hook_response",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "hook_id" => "hook-456",
      "hook_name" => "my-hook",
      "hook_event" => "PreToolUse",
      "stdout" => "Hook output",
      "stderr" => "Warning message",
      "output" => "Combined output",
      "exit_code" => 0,
      "outcome" => "success"
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::HookResponseMessage, msg
    assert_equal "msg-123", msg.uuid
    assert_equal "sess-abc", msg.session_id
    assert_equal "hook-456", msg.hook_id
    assert_equal "my-hook", msg.hook_name
    assert_equal "PreToolUse", msg.hook_event
    assert_equal "Hook output", msg.stdout
    assert_equal "Warning message", msg.stderr
    assert_equal "Combined output", msg.output
    assert_equal 0, msg.exit_code
    assert_equal "success", msg.outcome
    assert_equal :hook_response, msg.type
    assert msg.success?
  end

  test "parse_hook_response_message_camel_case" do
    raw = {
      "type" => "system",
      "subtype" => "hook_response",
      "uuid" => "msg-456",
      "sessionId" => "sess-xyz",
      "hookId" => "hook-789",
      "hookName" => "format-hook",
      "hookEvent" => "PostToolUse",
      "stdout" => "Formatted",
      "stderr" => "",
      "output" => "Formatted",
      "exitCode" => 1,
      "outcome" => "error"
    }
    msg = @parser.parse(raw)

    assert_equal "sess-xyz", msg.session_id
    assert_equal "hook-789", msg.hook_id
    assert_equal "format-hook", msg.hook_name
    assert_equal "PostToolUse", msg.hook_event
    assert_equal 1, msg.exit_code
    assert_equal "error", msg.outcome
    assert msg.error?
  end

  test "parse_hook_response_message_defaults" do
    raw = {
      "type" => "system",
      "subtype" => "hook_response",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "hook_name" => "my-hook",
      "hook_event" => "PreToolUse"
    }
    msg = @parser.parse(raw)

    assert_nil msg.hook_id
    assert_equal "", msg.stdout
    assert_equal "", msg.stderr
    assert_equal "", msg.output
    assert_nil msg.exit_code
    assert_nil msg.outcome
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

  test "parse_task_notification_message_with_tool_use_id_and_usage" do
    raw = {
      "type" => "system",
      "subtype" => "task_notification",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "task_id" => "task-456",
      "status" => "completed",
      "output_file" => "/path/to/output.txt",
      "summary" => "Done",
      "tool_use_id" => "tool-789",
      "usage" => { "total_tokens" => 5000, "tool_uses" => 3, "duration_ms" => 2500 }
    }
    msg = @parser.parse(raw)

    assert_equal "tool-789", msg.tool_use_id
    assert_instance_of ClaudeAgent::TaskUsage, msg.usage
    assert_equal 5000, msg.usage.total_tokens
    assert_equal 3, msg.usage.tool_uses
    assert_equal 2500, msg.usage.duration_ms
  end

  test "parse_task_notification_message_without_new_fields" do
    raw = {
      "type" => "system",
      "subtype" => "task_notification",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "task_id" => "task-456",
      "status" => "completed",
      "output_file" => "/path/to/output.txt",
      "summary" => "Done"
    }
    msg = @parser.parse(raw)

    assert_nil msg.tool_use_id
    assert_nil msg.usage
  end

  test "parse_task_notification_message_with_usage_camel_case" do
    raw = {
      "type" => "system",
      "subtype" => "task_notification",
      "uuid" => "msg-123",
      "sessionId" => "sess-abc",
      "taskId" => "task-456",
      "status" => "completed",
      "outputFile" => "/path/to/output.txt",
      "summary" => "Done",
      "toolUseId" => "tool-789",
      "usage" => { "totalTokens" => 10000, "toolUses" => 5, "durationMs" => 5000 }
    }
    msg = @parser.parse(raw)

    assert_equal "tool-789", msg.tool_use_id
    assert_instance_of ClaudeAgent::TaskUsage, msg.usage
    assert_equal 10000, msg.usage.total_tokens
    assert_equal 5, msg.usage.tool_uses
    assert_equal 5000, msg.usage.duration_ms
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

  # --- HookStartedMessage parsing ---

  test "parse_hook_started_message" do
    raw = {
      "type" => "system",
      "subtype" => "hook_started",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "hook_id" => "hook-456",
      "hook_name" => "my-hook",
      "hook_event" => "PreToolUse"
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::HookStartedMessage, msg
    assert_equal "msg-123", msg.uuid
    assert_equal "sess-abc", msg.session_id
    assert_equal "hook-456", msg.hook_id
    assert_equal "my-hook", msg.hook_name
    assert_equal "PreToolUse", msg.hook_event
    assert_equal :hook_started, msg.type
  end

  test "parse_hook_started_message_camel_case" do
    raw = {
      "type" => "system",
      "subtype" => "hook_started",
      "uuid" => "msg-456",
      "sessionId" => "sess-xyz",
      "hookId" => "hook-789",
      "hookName" => "format-hook",
      "hookEvent" => "PostToolUse"
    }
    msg = @parser.parse(raw)

    assert_equal "sess-xyz", msg.session_id
    assert_equal "hook-789", msg.hook_id
    assert_equal "format-hook", msg.hook_name
    assert_equal "PostToolUse", msg.hook_event
  end

  # --- HookProgressMessage parsing ---

  test "parse_hook_progress_message" do
    raw = {
      "type" => "system",
      "subtype" => "hook_progress",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "hook_id" => "hook-456",
      "hook_name" => "my-hook",
      "hook_event" => "PreToolUse",
      "stdout" => "Hook output",
      "stderr" => "Warning message",
      "output" => "Combined output"
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::HookProgressMessage, msg
    assert_equal "msg-123", msg.uuid
    assert_equal "sess-abc", msg.session_id
    assert_equal "hook-456", msg.hook_id
    assert_equal "my-hook", msg.hook_name
    assert_equal "PreToolUse", msg.hook_event
    assert_equal "Hook output", msg.stdout
    assert_equal "Warning message", msg.stderr
    assert_equal "Combined output", msg.output
    assert_equal :hook_progress, msg.type
  end

  test "parse_hook_progress_message_camel_case" do
    raw = {
      "type" => "system",
      "subtype" => "hook_progress",
      "uuid" => "msg-456",
      "sessionId" => "sess-xyz",
      "hookId" => "hook-789",
      "hookName" => "format-hook",
      "hookEvent" => "PostToolUse",
      "stdout" => "Output",
      "stderr" => "",
      "output" => "Output"
    }
    msg = @parser.parse(raw)

    assert_equal "sess-xyz", msg.session_id
    assert_equal "hook-789", msg.hook_id
    assert_equal "format-hook", msg.hook_name
    assert_equal "PostToolUse", msg.hook_event
  end

  test "parse_hook_progress_message_defaults" do
    raw = {
      "type" => "system",
      "subtype" => "hook_progress",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "hook_id" => "hook-456",
      "hook_name" => "my-hook",
      "hook_event" => "PreToolUse"
    }
    msg = @parser.parse(raw)

    assert_equal "", msg.stdout
    assert_equal "", msg.stderr
    assert_equal "", msg.output
  end

  # --- ToolUseSummaryMessage parsing ---

  test "parse_tool_use_summary_message" do
    raw = {
      "type" => "tool_use_summary",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "summary" => "Read 3 files",
      "preceding_tool_use_ids" => [ "tool-1", "tool-2", "tool-3" ]
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::ToolUseSummaryMessage, msg
    assert_equal "msg-123", msg.uuid
    assert_equal "sess-abc", msg.session_id
    assert_equal "Read 3 files", msg.summary
    assert_equal [ "tool-1", "tool-2", "tool-3" ], msg.preceding_tool_use_ids
    assert_equal :tool_use_summary, msg.type
  end

  test "parse_tool_use_summary_message_camel_case" do
    raw = {
      "type" => "tool_use_summary",
      "uuid" => "msg-456",
      "sessionId" => "sess-xyz",
      "summary" => "Wrote 2 files",
      "precedingToolUseIds" => [ "tool-a", "tool-b" ]
    }
    msg = @parser.parse(raw)

    assert_equal "sess-xyz", msg.session_id
    assert_equal "Wrote 2 files", msg.summary
    assert_equal [ "tool-a", "tool-b" ], msg.preceding_tool_use_ids
  end

  test "parse_tool_use_summary_message_defaults" do
    raw = {
      "type" => "tool_use_summary",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "summary" => "Read files"
    }
    msg = @parser.parse(raw)

    assert_equal [], msg.preceding_tool_use_ids
  end

  # --- FilesPersistedEvent parsing ---

  test "parse_files_persisted_event" do
    raw = {
      "type" => "system",
      "subtype" => "files_persisted",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "files" => [
        { "filename" => "test.rb", "file_id" => "file-456" }
      ],
      "failed" => [
        { "filename" => "bad.rb", "error" => "Permission denied" }
      ],
      "processed_at" => "2026-01-30T12:00:00Z"
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::FilesPersistedEvent, msg
    assert_equal "msg-123", msg.uuid
    assert_equal "sess-abc", msg.session_id
    assert_equal 1, msg.files.size
    assert_equal "test.rb", msg.files.first[:filename]
    assert_equal "file-456", msg.files.first[:file_id]
    assert_equal 1, msg.failed.size
    assert_equal "bad.rb", msg.failed.first[:filename]
    assert_equal "2026-01-30T12:00:00Z", msg.processed_at
    assert_equal :files_persisted, msg.type
  end

  test "parse_files_persisted_event_camel_case" do
    raw = {
      "type" => "system",
      "subtype" => "files_persisted",
      "uuid" => "msg-456",
      "sessionId" => "sess-xyz",
      "files" => [],
      "failed" => [],
      "processedAt" => "2026-01-30T13:00:00Z"
    }
    msg = @parser.parse(raw)

    assert_equal "sess-xyz", msg.session_id
    assert_equal "2026-01-30T13:00:00Z", msg.processed_at
  end

  test "parse_files_persisted_event_defaults" do
    raw = {
      "type" => "system",
      "subtype" => "files_persisted",
      "uuid" => "msg-123",
      "session_id" => "sess-abc"
    }
    msg = @parser.parse(raw)

    assert_equal [], msg.files
    assert_equal [], msg.failed
    assert_nil msg.processed_at
  end

  # --- TaskStartedMessage parsing ---

  test "parse_task_started_message" do
    raw = {
      "type" => "system",
      "subtype" => "task_started",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "task_id" => "task-456",
      "tool_use_id" => "tool-789",
      "description" => "Running tests",
      "task_type" => "bash"
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::TaskStartedMessage, msg
    assert_equal "msg-123", msg.uuid
    assert_equal "sess-abc", msg.session_id
    assert_equal "task-456", msg.task_id
    assert_equal "tool-789", msg.tool_use_id
    assert_equal "Running tests", msg.description
    assert_equal "bash", msg.task_type
    assert_equal :task_started, msg.type
  end

  test "parse_task_started_message_camel_case" do
    raw = {
      "type" => "system",
      "subtype" => "task_started",
      "uuid" => "msg-456",
      "sessionId" => "sess-xyz",
      "taskId" => "task-789",
      "toolUseId" => "tool-abc",
      "description" => "Exploring codebase",
      "taskType" => "explore"
    }
    msg = @parser.parse(raw)

    assert_equal "sess-xyz", msg.session_id
    assert_equal "task-789", msg.task_id
    assert_equal "tool-abc", msg.tool_use_id
    assert_equal "explore", msg.task_type
  end

  test "parse_task_started_message_defaults" do
    raw = {
      "type" => "system",
      "subtype" => "task_started",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "task_id" => "task-456"
    }
    msg = @parser.parse(raw)

    assert_nil msg.tool_use_id
    assert_nil msg.description
    assert_nil msg.task_type
  end

  # --- TaskProgressMessage parsing ---

  test "parse_task_progress_message" do
    raw = {
      "type" => "system",
      "subtype" => "task_progress",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "task_id" => "task-456",
      "tool_use_id" => "tool-789",
      "description" => "Searching codebase",
      "usage" => { "total_tokens" => 5000, "tool_uses" => 3, "duration_ms" => 2500 },
      "last_tool_name" => "Grep"
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::TaskProgressMessage, msg
    assert_equal "msg-123", msg.uuid
    assert_equal "sess-abc", msg.session_id
    assert_equal "task-456", msg.task_id
    assert_equal "tool-789", msg.tool_use_id
    assert_equal "Searching codebase", msg.description
    assert_equal 5000, msg.usage[:total_tokens]
    assert_equal 3, msg.usage[:tool_uses]
    assert_equal "Grep", msg.last_tool_name
    assert_equal :task_progress, msg.type
  end

  test "parse_task_progress_message_camel_case" do
    raw = {
      "type" => "system",
      "subtype" => "task_progress",
      "uuid" => "msg-456",
      "sessionId" => "sess-xyz",
      "taskId" => "task-789",
      "toolUseId" => "tool-abc",
      "description" => "Running tests",
      "usage" => { "totalTokens" => 10000, "toolUses" => 5, "durationMs" => 5000 },
      "lastToolName" => "Bash"
    }
    msg = @parser.parse(raw)

    assert_equal "sess-xyz", msg.session_id
    assert_equal "task-789", msg.task_id
    assert_equal "tool-abc", msg.tool_use_id
    assert_equal "Running tests", msg.description
    assert_equal "Bash", msg.last_tool_name
  end

  test "parse_task_progress_message_defaults" do
    raw = {
      "type" => "system",
      "subtype" => "task_progress",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "task_id" => "task-456",
      "description" => "Working"
    }
    msg = @parser.parse(raw)

    assert_nil msg.tool_use_id
    assert_nil msg.usage
    assert_nil msg.last_tool_name
  end

  # --- RateLimitEvent parsing ---

  test "parse_rate_limit_event" do
    raw = {
      "type" => "rate_limit_event",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "rate_limit_info" => {
        "status" => "allowed_warning",
        "resetsAt" => 1700000000,
        "rateLimitType" => "five_hour",
        "utilization" => 0.85,
        "isUsingOverage" => false,
        "overageStatus" => "available"
      }
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::RateLimitEvent, msg
    assert_equal "msg-123", msg.uuid
    assert_equal "sess-abc", msg.session_id
    assert_equal "allowed_warning", msg.status
    assert_equal 0.85, msg.rate_limit_info[:utilization]
    assert_equal :rate_limit_event, msg.type
  end

  test "parse_rate_limit_event_camel_case" do
    raw = {
      "type" => "rate_limit_event",
      "uuid" => "msg-456",
      "sessionId" => "sess-xyz",
      "rateLimitInfo" => {
        "status" => "blocked",
        "rateLimitType" => "daily"
      }
    }
    msg = @parser.parse(raw)

    assert_equal "sess-xyz", msg.session_id
    assert_equal "blocked", msg.status
  end

  test "parse_rate_limit_event_defaults" do
    raw = {
      "type" => "rate_limit_event",
      "uuid" => "msg-123",
      "session_id" => "sess-abc"
    }
    msg = @parser.parse(raw)

    assert_equal({}, msg.rate_limit_info)
    assert_nil msg.status
  end

  # --- PromptSuggestionMessage parsing ---

  test "parse_prompt_suggestion_message" do
    raw = {
      "type" => "prompt_suggestion",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "suggestion" => "Tell me about this project"
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::PromptSuggestionMessage, msg
    assert_equal "msg-123", msg.uuid
    assert_equal "sess-abc", msg.session_id
    assert_equal "Tell me about this project", msg.suggestion
    assert_equal :prompt_suggestion, msg.type
  end

  test "parse_prompt_suggestion_message_camel_case" do
    raw = {
      "type" => "prompt_suggestion",
      "uuid" => "msg-456",
      "sessionId" => "sess-xyz",
      "suggestion" => "How do I run the tests?"
    }
    msg = @parser.parse(raw)

    assert_equal "sess-xyz", msg.session_id
    assert_equal "How do I run the tests?", msg.suggestion
  end

  test "parse_prompt_suggestion_message_defaults" do
    raw = {
      "type" => "prompt_suggestion",
      "uuid" => "msg-123",
      "session_id" => "sess-abc"
    }
    msg = @parser.parse(raw)

    assert_equal "", msg.suggestion
  end

  # --- Parser Registry ---

  test "registry contains all top-level message types" do
    registry = ClaudeAgent::MessageParser.registry

    %w[user assistant result stream_event tool_progress auth_status
       tool_use_summary rate_limit_event prompt_suggestion].each do |type|
      assert registry.key?(type), "Registry should contain '#{type}'"
    end
  end

  test "registry contains all system subtypes" do
    registry = ClaudeAgent::MessageParser.registry

    %w[compact_boundary status hook_response task_notification hook_started
       hook_progress files_persisted task_started task_progress].each do |subtype|
      assert registry.key?("system:#{subtype}"), "Registry should contain 'system:#{subtype}'"
    end
  end

  test "registry contains system fallback" do
    assert ClaudeAgent::MessageParser.registry.key?("system")
  end

  test "registry routes unknown system subtype to system fallback" do
    raw = {
      "type" => "system",
      "subtype" => "future_subtype",
      "data" => { "info" => "new feature" }
    }
    msg = @parser.parse(raw)

    assert_instance_of ClaudeAgent::SystemMessage, msg
    assert_equal "future_subtype", msg.subtype
  end
end
