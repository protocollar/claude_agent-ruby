# frozen_string_literal: true

require "test_helper"

# Mock transport for testing stream_input
class MockStreamTransport
  attr_reader :written_messages

  def initialize(responses: [])
    @responses = responses
    @written_messages = []
    @response_index = 0
    @connected = false
  end

  def connect(streaming: true, prompt: nil)
    @connected = true
  end

  def connected?
    @connected
  end

  def write(data)
    @written_messages << JSON.parse(data)
  end

  def read_messages
    @responses.each do |response|
      yield response
    end
  end

  def end_input
  end

  def close
    @connected = false
  end

  def terminate(timeout: 5)
    @connected = false
  end
end

class TestClaudeAgentStreamInput < ActiveSupport::TestCase
  setup do
    @options = ClaudeAgent::Options.new
  end

  test "stream_input_with_string_messages" do
    transport = MockStreamTransport.new
    protocol = ClaudeAgent::ControlProtocol.new(transport: transport, options: @options)
    protocol.start(streaming: true)

    messages = [ "Hello", "World" ]
    protocol.stream_input(messages)

    # Check that messages were written
    user_messages = transport.written_messages.select { |m| m["type"] == "user" }
    assert_equal 2, user_messages.size
    assert_equal "Hello", user_messages[0].dig("message", "content")
    assert_equal "World", user_messages[1].dig("message", "content")
  end

  test "stream_input_with_hash_messages" do
    transport = MockStreamTransport.new
    protocol = ClaudeAgent::ControlProtocol.new(transport: transport, options: @options)
    protocol.start(streaming: true)

    messages = [
      { content: "Hello", uuid: "msg-1" },
      { content: "World", session_id: "custom-session" }
    ]
    protocol.stream_input(messages)

    user_messages = transport.written_messages.select { |m| m["type"] == "user" }
    assert_equal 2, user_messages.size
    assert_equal "Hello", user_messages[0].dig("message", "content")
    assert_equal "msg-1", user_messages[0]["uuid"]
    assert_equal "World", user_messages[1].dig("message", "content")
    assert_equal "custom-session", user_messages[1]["session_id"]
  end

  test "stream_input_with_user_message_objects" do
    transport = MockStreamTransport.new
    protocol = ClaudeAgent::ControlProtocol.new(transport: transport, options: @options)
    protocol.start(streaming: true)

    messages = [
      ClaudeAgent::UserMessage.new(content: "Hello", uuid: "msg-1", session_id: "sess-1"),
      ClaudeAgent::UserMessage.new(content: "World")
    ]
    protocol.stream_input(messages)

    user_messages = transport.written_messages.select { |m| m["type"] == "user" }
    assert_equal 2, user_messages.size
    assert_equal "Hello", user_messages[0].dig("message", "content")
    assert_equal "msg-1", user_messages[0]["uuid"]
    assert_equal "sess-1", user_messages[0]["session_id"]
  end

  test "stream_input_with_user_message_replay" do
    transport = MockStreamTransport.new
    protocol = ClaudeAgent::ControlProtocol.new(transport: transport, options: @options)
    protocol.start(streaming: true)

    messages = [
      ClaudeAgent::UserMessageReplay.new(content: "Replayed message", uuid: "replay-1")
    ]
    protocol.stream_input(messages)

    user_messages = transport.written_messages.select { |m| m["type"] == "user" }
    assert_equal 1, user_messages.size
    assert_equal "Replayed message", user_messages[0].dig("message", "content")
    assert_equal "replay-1", user_messages[0]["uuid"]
  end

  test "stream_input_uses_default_session_id" do
    transport = MockStreamTransport.new
    protocol = ClaudeAgent::ControlProtocol.new(transport: transport, options: @options)
    protocol.start(streaming: true)

    protocol.stream_input([ "Hello" ], session_id: "my-session")

    user_messages = transport.written_messages.select { |m| m["type"] == "user" }
    assert_equal "my-session", user_messages[0]["session_id"]
  end

  test "stream_input_raises_on_unknown_type" do
    transport = MockStreamTransport.new
    protocol = ClaudeAgent::ControlProtocol.new(transport: transport, options: @options)
    protocol.start(streaming: true)

    assert_raises(ArgumentError) do
      protocol.stream_input([ 12345 ])
    end
  end

  test "stream_input_with_abort_signal" do
    controller = ClaudeAgent::AbortController.new
    options = ClaudeAgent::Options.new(abort_controller: controller)
    transport = MockStreamTransport.new
    protocol = ClaudeAgent::ControlProtocol.new(transport: transport, options: options)
    protocol.start(streaming: true)

    # Create an enumerator that aborts after first message
    messages = Enumerator.new do |y|
      y << "First"
      controller.abort("Cancelled")
      y << "Second"
    end

    assert_raises(ClaudeAgent::AbortError) do
      protocol.stream_input(messages)
    end

    # Only first message should be written
    user_messages = transport.written_messages.select { |m| m["type"] == "user" }
    assert_equal 1, user_messages.size
  end

  test "stream_input_with_string_keys_in_hash" do
    transport = MockStreamTransport.new
    protocol = ClaudeAgent::ControlProtocol.new(transport: transport, options: @options)
    protocol.start(streaming: true)

    messages = [
      { "content" => "Hello", "uuid" => "msg-1", "session_id" => "sess-1" }
    ]
    protocol.stream_input(messages)

    user_messages = transport.written_messages.select { |m| m["type"] == "user" }
    assert_equal "Hello", user_messages[0].dig("message", "content")
    assert_equal "msg-1", user_messages[0]["uuid"]
    assert_equal "sess-1", user_messages[0]["session_id"]
  end
end

class TestClaudeAgentClientStreamInput < ActiveSupport::TestCase
  test "client_stream_input_requires_connection" do
    client = ClaudeAgent::Client.new

    assert_raises(ClaudeAgent::CLIConnectionError) do
      client.stream_input([ "Hello" ])
    end
  end
end
