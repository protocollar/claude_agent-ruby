# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentMessagesConversation < ActiveSupport::TestCase
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
end
