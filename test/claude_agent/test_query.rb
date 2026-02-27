# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentQuery < ActiveSupport::TestCase
  test "query simple mode" do
    responses = [
      {
        "type" => "assistant",
        "message" => {
          "model" => "claude",
          "content" => [ { "type" => "text", "text" => "The answer is 4" } ]
        }
      },
      {
        "type" => "result",
        "subtype" => "success",
        "duration_ms" => 500,
        "duration_api_ms" => 400,
        "is_error" => false,
        "num_turns" => 1,
        "session_id" => "test-session",
        "total_cost_usd" => 0.001
      }
    ]

    transport = MockTransport.new(responses: responses)
    messages = ClaudeAgent.query(prompt: "What is 2+2?", transport: transport).to_a

    assert_equal 2, messages.length
    assert_instance_of ClaudeAgent::AssistantMessage, messages[0]
    assert_equal "The answer is 4", messages[0].text
    assert_instance_of ClaudeAgent::ResultMessage, messages[1]
    assert_equal 0.001, messages[1].total_cost_usd
  end

  test "query returns enumerator" do
    transport = MockTransport.new(responses: [])
    result = ClaudeAgent.query(prompt: "Hello", transport: transport)

    assert_instance_of Enumerator, result
  end

  test "query with options" do
    responses = [
      {
        "type" => "result",
        "subtype" => "success",
        "duration_ms" => 100,
        "duration_api_ms" => 80,
        "is_error" => false,
        "num_turns" => 1,
        "session_id" => "test"
      }
    ]

    options = ClaudeAgent::Options.new(
      model: "claude-sonnet-4-5-20250514",
      max_turns: 5
    )
    transport = MockTransport.new(responses: responses)

    messages = ClaudeAgent.query(prompt: "Hello", options: options, transport: transport).to_a

    assert_equal 1, messages.length
    assert_instance_of ClaudeAgent::ResultMessage, messages[0]
  end

  test "query stops at result" do
    responses = [
      {
        "type" => "assistant",
        "message" => { "model" => "claude", "content" => [ { "type" => "text", "text" => "First" } ] }
      },
      {
        "type" => "result",
        "subtype" => "success",
        "duration_ms" => 100,
        "duration_api_ms" => 80,
        "is_error" => false,
        "num_turns" => 1,
        "session_id" => "test"
      },
      # This should not be yielded
      {
        "type" => "assistant",
        "message" => { "model" => "claude", "content" => [ { "type" => "text", "text" => "Should not appear" } ] }
      }
    ]

    transport = MockTransport.new(responses: responses)
    messages = ClaudeAgent.query(prompt: "Hello", transport: transport).to_a

    assert_equal 2, messages.length
    assert_instance_of ClaudeAgent::AssistantMessage, messages[0]
    assert_instance_of ClaudeAgent::ResultMessage, messages[1]
  end

  test "query with tool use" do
    responses = [
      {
        "type" => "assistant",
        "message" => {
          "model" => "claude",
          "content" => [
            { "type" => "text", "text" => "Let me read that file" },
            { "type" => "tool_use", "id" => "tool_123", "name" => "Read", "input" => { "file_path" => "/tmp/test" } }
          ]
        }
      },
      {
        "type" => "user",
        "message" => {
          "content" => [ { "type" => "tool_result", "tool_use_id" => "tool_123", "content" => "file contents" } ]
        }
      },
      {
        "type" => "assistant",
        "message" => {
          "model" => "claude",
          "content" => [ { "type" => "text", "text" => "The file contains: file contents" } ]
        }
      },
      {
        "type" => "result",
        "subtype" => "success",
        "duration_ms" => 1000,
        "duration_api_ms" => 900,
        "is_error" => false,
        "num_turns" => 2,
        "session_id" => "test"
      }
    ]

    transport = MockTransport.new(responses: responses)
    messages = ClaudeAgent.query(prompt: "Read /tmp/test", transport: transport).to_a

    assert_equal 4, messages.length

    # First assistant message with tool use
    assert messages[0].has_tool_use?
    assert_equal "Read", messages[0].tool_uses.first.name

    # Tool result
    assert_instance_of ClaudeAgent::UserMessage, messages[1]

    # Second assistant message
    assert_match(/file contents/, messages[2].text)

    # Final result
    assert_equal 2, messages[3].num_turns
  end
end
