# frozen_string_literal: true

require_relative "../integration_helper"

class TestIntegrationMessageParser < IntegrationTestCase
  def setup
    super
    @parser = ClaudeAgent::MessageParser.new
  end

  test "message parser - user message" do
    raw = {
      "type" => "user",
      "message" => { "content" => "Hello", "role" => "user" },
      "uuid" => "test-uuid"
    }

    msg = @parser.parse(raw)
    assert_kind_of ClaudeAgent::UserMessage, msg
    assert_equal "Hello", msg.content
    assert_equal "test-uuid", msg.uuid
  end

  test "message parser - assistant message" do
    raw = {
      "type" => "assistant",
      "message" => {
        "content" => [ { "type" => "text", "text" => "Hi there" } ],
        "model" => "claude-sonnet-4-5-20250514"
      }
    }

    msg = @parser.parse(raw)
    assert_kind_of ClaudeAgent::AssistantMessage, msg
    assert_equal "Hi there", msg.text
    assert_equal "claude-sonnet-4-5-20250514", msg.model
  end

  test "message parser - tool use in assistant message" do
    raw = {
      "type" => "assistant",
      "message" => {
        "content" => [
          { "type" => "text", "text" => "Let me read that file." },
          { "type" => "tool_use", "id" => "tool_123", "name" => "Read", "input" => { "file_path" => "/tmp" } }
        ],
        "model" => "claude-sonnet-4-5-20250514"
      }
    }

    msg = @parser.parse(raw)
    assert_kind_of ClaudeAgent::AssistantMessage, msg
    assert msg.has_tool_use?
    assert_equal 1, msg.tool_uses.length
    assert_equal "Read", msg.tool_uses.first.name
  end

  test "message parser - image content block" do
    raw = {
      "type" => "assistant",
      "message" => {
        "content" => [
          {
            "type" => "image",
            "source" => {
              "type" => "base64",
              "media_type" => "image/png",
              "data" => "iVBORw0KGgo..."
            }
          }
        ],
        "model" => "claude-sonnet-4-5-20250514"
      }
    }

    msg = @parser.parse(raw)
    assert_kind_of ClaudeAgent::AssistantMessage, msg
    assert_equal 1, msg.content.length

    block = msg.content.first
    assert_kind_of ClaudeAgent::ImageContentBlock, block
    assert_equal :image, block.type
    assert_equal "base64", block.source_type
    assert_equal "image/png", block.media_type
    assert_equal "iVBORw0KGgo...", block.data
  end

  test "message parser - compact boundary message" do
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
    assert_kind_of ClaudeAgent::CompactBoundaryMessage, msg
    assert_equal :compact_boundary, msg.type
    assert_equal "msg-123", msg.uuid
    assert_equal "sess-abc", msg.session_id
    assert_equal "auto", msg.trigger
    assert_equal 50000, msg.pre_tokens

    raw_camel = {
      "type" => "system",
      "subtype" => "compact_boundary",
      "uuid" => "msg-456",
      "sessionId" => "sess-xyz",
      "compactMetadata" => {
        "trigger" => "manual",
        "pre_tokens" => 25000
      }
    }

    msg_camel = @parser.parse(raw_camel)
    assert_kind_of ClaudeAgent::CompactBoundaryMessage, msg_camel
    assert_equal "sess-xyz", msg_camel.session_id
    assert_equal "manual", msg_camel.trigger
    assert_equal 25000, msg_camel.pre_tokens
  end

  test "message parser - user message with isReplay flag" do
    raw = {
      "type" => "user",
      "uuid" => "msg-123",
      "isReplay" => true,
      "isSynthetic" => true,
      "toolUseResult" => { "tool_use_id" => "tool-456" },
      "message" => { "content" => "Hello replay" }
    }

    msg = @parser.parse(raw)
    assert_kind_of ClaudeAgent::UserMessageReplay, msg
    assert msg.replay?, "Expected replay? to be true"
    assert msg.synthetic?, "Expected synthetic? to be true"
    assert_equal({ "tool_use_id" => "tool-456" }, msg.tool_use_result)
    assert_equal "Hello replay", msg.content

    raw_snake = {
      "type" => "user",
      "uuid" => "msg-456",
      "is_replay" => true,
      "is_synthetic" => false,
      "tool_use_result" => { "data" => "value" },
      "message" => { "content" => "Snake case replay" }
    }

    msg_snake = @parser.parse(raw_snake)
    assert_kind_of ClaudeAgent::UserMessageReplay, msg_snake
    assert msg_snake.replay?
    assert !msg_snake.synthetic?

    raw_normal = {
      "type" => "user",
      "uuid" => "msg-789",
      "message" => { "content" => "Normal message" }
    }

    msg_normal = @parser.parse(raw_normal)
    assert_kind_of ClaudeAgent::UserMessage, msg_normal
    assert !msg_normal.is_a?(ClaudeAgent::UserMessageReplay)
    assert !msg_normal.replay?
  end

  test "message parser - new message types" do
    status_raw = {
      "type" => "system",
      "subtype" => "status",
      "uuid" => "msg-123",
      "session_id" => "sess-abc",
      "status" => "compacting"
    }
    status = @parser.parse(status_raw)
    assert_kind_of ClaudeAgent::StatusMessage, status
    assert_equal "compacting", status.status

    progress_raw = {
      "type" => "tool_progress",
      "uuid" => "msg-456",
      "session_id" => "sess-abc",
      "tool_use_id" => "tool-789",
      "tool_name" => "Bash",
      "elapsed_time_seconds" => 5.2
    }
    progress = @parser.parse(progress_raw)
    assert_kind_of ClaudeAgent::ToolProgressMessage, progress
    assert_equal "Bash", progress.tool_name
    assert_equal 5.2, progress.elapsed_time_seconds

    hook_raw = {
      "type" => "system",
      "subtype" => "hook_response",
      "uuid" => "msg-789",
      "session_id" => "sess-abc",
      "hook_name" => "my-hook",
      "hook_event" => "PreToolUse",
      "stdout" => "output",
      "stderr" => "",
      "exit_code" => 0
    }
    hook = @parser.parse(hook_raw)
    assert_kind_of ClaudeAgent::HookResponseMessage, hook
    assert_equal "my-hook", hook.hook_name
    assert_equal 0, hook.exit_code

    auth_raw = {
      "type" => "auth_status",
      "uuid" => "msg-111",
      "session_id" => "sess-abc",
      "is_authenticating" => true,
      "output" => [ "Waiting for browser..." ]
    }
    auth = @parser.parse(auth_raw)
    assert_kind_of ClaudeAgent::AuthStatusMessage, auth
    assert auth.is_authenticating
    assert_equal [ "Waiting for browser..." ], auth.output
  end
end
