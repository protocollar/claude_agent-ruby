# frozen_string_literal: true

require_relative "../smoke_helper"

class TestSmokeBasic < SmokeTestCase
  test "basic query returns result" do
    messages = ClaudeAgent.query(
      prompt: "Reply with exactly: PING",
      options: test_options
    ).to_a

    result = messages.find { |m| m.is_a?(ClaudeAgent::ResultMessage) }
    assert_not_nil result, "Expected ResultMessage"
    assert_equal false, result.is_error
  end

  test "client lifecycle" do
    assistant_message = nil
    result_message = nil

    ClaudeAgent::Client.open(options: test_options) do |client|
      client.query("Reply with exactly: SMOKE")

      client.receive_response.each do |msg|
        assistant_message = msg if msg.is_a?(ClaudeAgent::AssistantMessage)
        result_message = msg if msg.is_a?(ClaudeAgent::ResultMessage)
        break if result_message
      end
    end

    assert_not_nil assistant_message, "Expected AssistantMessage"
    assert_not_nil result_message, "Expected ResultMessage"
    assert_equal false, result_message.is_error
  end

  test "conversation say and close" do
    conversation = ClaudeAgent::Conversation.new(options: test_options)

    turn = conversation.say("Reply with exactly: HELLO")

    assert_instance_of ClaudeAgent::TurnResult, turn
    assert turn.complete?
    assert turn.success?
  ensure
    conversation&.close
  end
end
