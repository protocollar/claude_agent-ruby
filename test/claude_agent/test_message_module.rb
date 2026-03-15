# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentMessageModule < ActiveSupport::TestCase
  # --- text_content ---

  test "text_content on AssistantMessage" do
    msg = ClaudeAgent::AssistantMessage.new(
      content: [ ClaudeAgent::TextBlock.new(text: "Hello!") ],
      model: "claude"
    )
    assert_equal "Hello!", msg.text_content
  end

  test "text_content on UserMessage with string content" do
    msg = ClaudeAgent::UserMessage.new(content: "Hello!")
    assert_equal "Hello!", msg.text_content
  end

  test "text_content on UserMessage with array content" do
    msg = ClaudeAgent::UserMessage.new(content: [ { type: "text", text: "hi" } ])
    assert_equal "", msg.text_content
  end

  test "text_content on TextBlock" do
    block = ClaudeAgent::TextBlock.new(text: "block text")
    assert_equal "block text", block.text_content
  end

  test "text_content on ThinkingBlock" do
    block = ClaudeAgent::ThinkingBlock.new(thinking: "thinking...", signature: "abc")
    assert_equal "thinking...", block.text_content
  end

  test "text_content on ResultMessage" do
    msg = ClaudeAgent::ResultMessage.new(
      subtype: "success", duration_ms: 100, duration_api_ms: 80,
      is_error: false, num_turns: 1, session_id: "s1"
    )
    assert_equal "", msg.text_content
  end

  test "text_content on StreamEvent with text delta" do
    msg = ClaudeAgent::StreamEvent.new(
      uuid: "e1", session_id: "s1",
      event: { type: "content_block_delta", delta: { type: "text_delta", text: "streamed" } }
    )
    assert_equal "streamed", msg.text_content
  end

  test "text_content on StreamEvent without text delta" do
    msg = ClaudeAgent::StreamEvent.new(
      uuid: "e1", session_id: "s1",
      event: { type: "content_block_start" }
    )
    assert_equal "", msg.text_content
  end

  test "text_content on SystemMessage" do
    msg = ClaudeAgent::SystemMessage.new(subtype: "init", data: {})
    assert_equal "", msg.text_content
  end

  # --- session_message? ---

  test "session_message? true for AssistantMessage with both fields" do
    msg = ClaudeAgent::AssistantMessage.new(
      content: [], model: "claude", uuid: "u1", session_id: "s1"
    )
    assert msg.session_message?
  end

  test "session_message? false for AssistantMessage without uuid" do
    msg = ClaudeAgent::AssistantMessage.new(content: [], model: "claude")
    refute msg.session_message?
  end

  test "session_message? false for SystemMessage without uuid" do
    msg = ClaudeAgent::SystemMessage.new(subtype: "init", data: {})
    refute msg.session_message?
  end

  test "session_message? false for TextBlock" do
    block = ClaudeAgent::TextBlock.new(text: "hello")
    refute block.session_message?
  end

  # --- identifiable? ---

  test "identifiable? true with uuid" do
    msg = ClaudeAgent::StatusMessage.new(uuid: "u1", session_id: "s1", status: "ok")
    assert msg.identifiable?
  end

  test "identifiable? false without uuid" do
    block = ClaudeAgent::TextBlock.new(text: "hello")
    refute block.identifiable?
  end

  # --- deconstruct_keys (pattern matching) ---

  test "deconstruct_keys includes type" do
    msg = ClaudeAgent::TextBlock.new(text: "hello")
    keys = msg.deconstruct_keys(nil)
    assert_equal :text, keys[:type]
    assert_equal "hello", keys[:text]
  end

  test "deconstruct_keys with specific keys includes type" do
    msg = ClaudeAgent::TextBlock.new(text: "hello")
    keys = msg.deconstruct_keys([ :type, :text ])
    assert_equal :text, keys[:type]
    assert_equal "hello", keys[:text]
  end

  test "deconstruct_keys without type key omits type" do
    msg = ClaudeAgent::TextBlock.new(text: "hello")
    keys = msg.deconstruct_keys([ :text ])
    refute keys.key?(:type)
    assert_equal "hello", keys[:text]
  end

  test "pattern matching works with message types" do
    msg = ClaudeAgent::TextBlock.new(text: "hello")
    matched = case msg
    in { type: :text, text: String => t }
      t
    else
      nil
    end
    assert_equal "hello", matched
  end

  test "pattern matching works with assistant message" do
    msg = ClaudeAgent::AssistantMessage.new(
      content: [ ClaudeAgent::TextBlock.new(text: "hi") ],
      model: "claude"
    )
    matched = case msg
    in { type: :assistant }
      true
    else
      false
    end
    assert matched
  end

  # --- Module inclusion ---

  test "all MESSAGE_TYPES include Message" do
    ClaudeAgent::MESSAGE_TYPES.each do |klass|
      assert klass.ancestors.include?(ClaudeAgent::Message),
        "#{klass} should include ClaudeAgent::Message"
    end
  end

  test "all CONTENT_BLOCK_TYPES include Message" do
    ClaudeAgent::CONTENT_BLOCK_TYPES.each do |klass|
      assert klass.ancestors.include?(ClaudeAgent::Message),
        "#{klass} should include ClaudeAgent::Message"
    end
  end
end
