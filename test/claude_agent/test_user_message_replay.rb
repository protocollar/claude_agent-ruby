# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentUserMessageReplay < ActiveSupport::TestCase
  test "user_message_replay_initialization" do
    msg = ClaudeAgent::UserMessageReplay.new(
      content: "Hello",
      uuid: "msg-123",
      session_id: "session-abc"
    )

    assert_equal "Hello", msg.content
    assert_equal "msg-123", msg.uuid
    assert_equal "session-abc", msg.session_id
    assert msg.replay?
  end

  test "user_message_replay_type" do
    msg = ClaudeAgent::UserMessageReplay.new(content: "test")
    assert_equal :user, msg.type
  end

  test "user_message_replay_text_with_string_content" do
    msg = ClaudeAgent::UserMessageReplay.new(content: "Hello world")
    assert_equal "Hello world", msg.text
  end

  test "user_message_replay_text_with_non_string_content" do
    msg = ClaudeAgent::UserMessageReplay.new(content: [ { type: "text", text: "Hello" } ])
    assert_nil msg.text
  end

  test "user_message_replay_is_replay_true" do
    msg = ClaudeAgent::UserMessageReplay.new(content: "test", is_replay: true)
    assert msg.replay?
  end

  test "user_message_replay_default_is_replay" do
    msg = ClaudeAgent::UserMessageReplay.new(content: "test")
    assert msg.replay?
  end

  test "user_message_replay_synthetic" do
    msg = ClaudeAgent::UserMessageReplay.new(content: "test", is_synthetic: true)
    assert msg.synthetic?
  end

  test "user_message_replay_not_synthetic_by_default" do
    msg = ClaudeAgent::UserMessageReplay.new(content: "test")
    refute msg.synthetic?
  end

  test "user_message_replay_tool_use_result" do
    result = { "tool_use_id" => "tool-123", "content" => "output" }
    msg = ClaudeAgent::UserMessageReplay.new(content: "test", tool_use_result: result)

    assert_equal result, msg.tool_use_result
  end

  test "user_message_replay_all_fields" do
    msg = ClaudeAgent::UserMessageReplay.new(
      content: "Hello",
      uuid: "msg-123",
      session_id: "session-abc",
      parent_tool_use_id: "parent-456",
      is_replay: true,
      is_synthetic: true,
      tool_use_result: { "data" => "value" }
    )

    assert_equal "Hello", msg.content
    assert_equal "msg-123", msg.uuid
    assert_equal "session-abc", msg.session_id
    assert_equal "parent-456", msg.parent_tool_use_id
    assert msg.replay?
    assert msg.synthetic?
    assert_equal({ "data" => "value" }, msg.tool_use_result)
  end

  test "user_message_is_not_replay" do
    msg = ClaudeAgent::UserMessage.new(content: "test")
    refute msg.replay?
  end

  test "user_message_replay_in_message_types" do
    assert_includes ClaudeAgent::MESSAGE_TYPES, ClaudeAgent::UserMessageReplay
  end
end

class TestClaudeAgentMessageParserReplay < ActiveSupport::TestCase
  setup do
    @parser = ClaudeAgent::MessageParser.new
  end

  test "parses_user_message_without_replay_flag" do
    raw = {
      "type" => "user",
      "uuid" => "msg-123",
      "message" => { "content" => "Hello" }
    }

    msg = @parser.parse(raw)

    assert_kind_of ClaudeAgent::UserMessage, msg
    refute_kind_of ClaudeAgent::UserMessageReplay, msg
    refute msg.replay?
  end

  test "parses_user_message_with_is_replay_true" do
    raw = {
      "type" => "user",
      "uuid" => "msg-123",
      "isReplay" => true,
      "message" => { "content" => "Hello" }
    }

    msg = @parser.parse(raw)

    assert_kind_of ClaudeAgent::UserMessageReplay, msg
    assert msg.replay?
    assert_equal "Hello", msg.content
    assert_equal "msg-123", msg.uuid
  end

  test "parses_user_message_with_snake_case_is_replay" do
    raw = {
      "type" => "user",
      "uuid" => "msg-123",
      "is_replay" => true,
      "message" => { "content" => "Test" }
    }

    msg = @parser.parse(raw)

    assert_kind_of ClaudeAgent::UserMessageReplay, msg
    assert msg.replay?
  end

  test "parses_user_message_replay_with_synthetic" do
    raw = {
      "type" => "user",
      "isReplay" => true,
      "isSynthetic" => true,
      "message" => { "content" => "Synthetic message" }
    }

    msg = @parser.parse(raw)

    assert_kind_of ClaudeAgent::UserMessageReplay, msg
    assert msg.replay?
    assert msg.synthetic?
  end

  test "parses_user_message_replay_with_snake_case_synthetic" do
    raw = {
      "type" => "user",
      "is_replay" => true,
      "is_synthetic" => true,
      "message" => { "content" => "Synthetic message" }
    }

    msg = @parser.parse(raw)

    assert msg.synthetic?
  end

  test "parses_user_message_replay_with_tool_use_result" do
    raw = {
      "type" => "user",
      "isReplay" => true,
      "toolUseResult" => { "tool_use_id" => "tool-123", "content" => "result" },
      "message" => { "content" => "Tool result message" }
    }

    msg = @parser.parse(raw)

    assert_kind_of ClaudeAgent::UserMessageReplay, msg
    assert_equal({ "tool_use_id" => "tool-123", "content" => "result" }, msg.tool_use_result)
  end

  test "parses_user_message_replay_with_snake_case_tool_use_result" do
    raw = {
      "type" => "user",
      "is_replay" => true,
      "tool_use_result" => { "tool_use_id" => "tool-456", "content" => "output" },
      "message" => { "content" => "Tool result" }
    }

    msg = @parser.parse(raw)

    assert_equal({ "tool_use_id" => "tool-456", "content" => "output" }, msg.tool_use_result)
  end

  test "parses_user_message_replay_with_session_id" do
    raw = {
      "type" => "user",
      "isReplay" => true,
      "uuid" => "msg-789",
      "sessionId" => "session-xyz",
      "message" => { "content" => "Session test" }
    }

    msg = @parser.parse(raw)

    assert_equal "session-xyz", msg.session_id
    assert_equal "msg-789", msg.uuid
  end

  test "parses_user_message_replay_with_parent_tool_use_id" do
    raw = {
      "type" => "user",
      "isReplay" => true,
      "parent_tool_use_id" => "parent-123",
      "message" => { "content" => "Child message" }
    }

    msg = @parser.parse(raw)

    assert_equal "parent-123", msg.parent_tool_use_id
  end
end
