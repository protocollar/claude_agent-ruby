# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentControlProtocolMessaging < ActiveSupport::TestCase
  setup do
    @transport = MockTransport.new
    @options = ClaudeAgent::Options.new
    @protocol = ClaudeAgent::ControlProtocol.new(transport: @transport, options: @options)
  end

  test "send user message" do
    @transport.connect
    @protocol.send_user_message("Hello!", session_id: "test-session")

    assert_equal 1, @transport.written_messages.length
    msg = @transport.written_messages.first

    assert_equal "user", msg["type"]
    assert_equal "user", msg["message"]["role"]
    assert_equal "Hello!", msg["message"]["content"]
    assert_equal "test-session", msg["session_id"]
  end

  test "send user message with uuid" do
    @transport.connect
    @protocol.send_user_message("Hello!", session_id: "test", uuid: "msg-123")

    msg = @transport.written_messages.first
    assert_equal "msg-123", msg["uuid"]
  end
end
