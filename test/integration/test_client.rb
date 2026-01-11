# frozen_string_literal: true

require_relative "../integration_helper"

class TestIntegrationClient < IntegrationTestCase
  test "client streaming mode" do
    client = ClaudeAgent::Client.new(options: test_options)

    client.connect
    assert client.connected?, "Client should be connected"

    client.query("Reply with: TEST")

    messages = []
    client.receive_response.each do |msg|
      messages << msg
      break if msg.is_a?(ClaudeAgent::ResultMessage)
    end

    assert messages.any? { |m| m.is_a?(ClaudeAgent::AssistantMessage) }
    assert messages.any? { |m| m.is_a?(ClaudeAgent::ResultMessage) }

    client.disconnect
    assert !client.connected?, "Client should be disconnected"
  end

  test "client block syntax" do
    result_message = nil

    ClaudeAgent::Client.open(options: test_options) do |client|
      client.query("Reply with: BLOCK")
      client.receive_response.each do |msg|
        result_message = msg if msg.is_a?(ClaudeAgent::ResultMessage)
        break if result_message
      end
    end

    assert_not_nil result_message
    assert_equal false, result_message.is_error
  end

  test "multi-turn conversation" do
    ClaudeAgent::Client.open(options: test_options) do |client|
      # First query
      client.query("Remember the number 42")
      first_result = nil
      client.receive_response.each do |msg|
        first_result = msg if msg.is_a?(ClaudeAgent::ResultMessage)
        break if first_result
      end
      assert_not_nil first_result

      # Second query in same session
      client.query("What number did I ask you to remember? Reply with just the number.")
      second_result = nil
      assistant_response = nil
      client.receive_response.each do |msg|
        assistant_response = msg if msg.is_a?(ClaudeAgent::AssistantMessage)
        second_result = msg if msg.is_a?(ClaudeAgent::ResultMessage)
        break if second_result
      end

      assert_not_nil second_result
      assert_not_nil assistant_response
      assert assistant_response.text.include?("42"), "Expected response to contain '42'"
    end
  end
end
