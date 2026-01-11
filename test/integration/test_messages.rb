# frozen_string_literal: true

require_relative "../integration_helper"

class TestIntegrationMessages < IntegrationTestCase
  test "message type constants" do
    assert ClaudeAgent::MESSAGE_TYPES.include?(ClaudeAgent::UserMessage)
    assert ClaudeAgent::MESSAGE_TYPES.include?(ClaudeAgent::AssistantMessage)
    assert ClaudeAgent::MESSAGE_TYPES.include?(ClaudeAgent::SystemMessage)
    assert ClaudeAgent::MESSAGE_TYPES.include?(ClaudeAgent::ResultMessage)
    assert ClaudeAgent::MESSAGE_TYPES.include?(ClaudeAgent::StreamEvent)
  end

  test "content block types" do
    assert ClaudeAgent::CONTENT_BLOCK_TYPES.include?(ClaudeAgent::TextBlock)
    assert ClaudeAgent::CONTENT_BLOCK_TYPES.include?(ClaudeAgent::ThinkingBlock)
    assert ClaudeAgent::CONTENT_BLOCK_TYPES.include?(ClaudeAgent::ToolUseBlock)
    assert ClaudeAgent::CONTENT_BLOCK_TYPES.include?(ClaudeAgent::ToolResultBlock)

    block = ClaudeAgent::TextBlock.new(text: "Hello")
    assert_equal :text, block.type
    assert_equal "Hello", block.text

    thinking = ClaudeAgent::ThinkingBlock.new(thinking: "Hmm", signature: "abc")
    assert_equal :thinking, thinking.type

    tool = ClaudeAgent::ToolUseBlock.new(id: "123", name: "Read", input: { path: "/tmp" })
    assert_equal :tool_use, tool.type
    assert_equal "Read", tool.name
  end

  test "new message types in MESSAGE_TYPES" do
    assert ClaudeAgent::MESSAGE_TYPES.include?(ClaudeAgent::StatusMessage)
    assert ClaudeAgent::MESSAGE_TYPES.include?(ClaudeAgent::ToolProgressMessage)
    assert ClaudeAgent::MESSAGE_TYPES.include?(ClaudeAgent::HookResponseMessage)
    assert ClaudeAgent::MESSAGE_TYPES.include?(ClaudeAgent::AuthStatusMessage)
  end

  test "session_id field on UserMessage and AssistantMessage" do
    user_msg = ClaudeAgent::UserMessage.new(
      content: "Hello",
      uuid: "msg-123",
      session_id: "sess-abc"
    )
    assert_equal "sess-abc", user_msg.session_id

    assistant_msg = ClaudeAgent::AssistantMessage.new(
      content: [ ClaudeAgent::TextBlock.new(text: "Hi") ],
      model: "claude",
      uuid: "msg-456",
      session_id: "sess-xyz"
    )
    assert_equal "sess-xyz", assistant_msg.session_id
  end

  test "ResultMessage new fields" do
    result = ClaudeAgent::ResultMessage.new(
      subtype: "success",
      duration_ms: 1000,
      duration_api_ms: 800,
      is_error: false,
      num_turns: 1,
      session_id: "session_123",
      total_cost_usd: 0.01,
      usage: { input_tokens: 100, output_tokens: 50 },
      result: "Done",
      structured_output: nil,
      errors: [ "warning: deprecated API" ],
      permission_denials: [
        ClaudeAgent::SDKPermissionDenial.new(
          tool_name: "Write",
          tool_use_id: "tool_456",
          tool_input: { file_path: "/etc/passwd" }
        )
      ],
      model_usage: { "claude-sonnet-4-5-20250514" => { input_tokens: 100 } }
    )

    assert_equal [ "warning: deprecated API" ], result.errors
    assert_equal 1, result.permission_denials.length
    assert_equal "Write", result.permission_denials.first.tool_name
    assert result.model_usage.key?("claude-sonnet-4-5-20250514")
  end
end
