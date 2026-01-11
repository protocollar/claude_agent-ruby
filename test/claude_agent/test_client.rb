# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentClient < ActiveSupport::TestCase
  test "client initialization" do
    client = ClaudeAgent::Client.new
    refute client.connected?
    assert_instance_of ClaudeAgent::Options, client.options
  end

  test "client with options" do
    options = ClaudeAgent::Options.new(model: "claude-sonnet-4-5-20250514")
    client = ClaudeAgent::Client.new(options: options)
    assert_equal "claude-sonnet-4-5-20250514", client.options.model
  end

  test "client connect disconnect" do
    transport = MockTransport.new
    client = ClaudeAgent::Client.new(transport: transport)

    refute client.connected?

    client.connect
    assert client.connected?

    client.disconnect
    refute client.connected?
  end

  test "client connect twice raises" do
    transport = MockTransport.new
    client = ClaudeAgent::Client.new(transport: transport)
    client.connect

    assert_raises(ClaudeAgent::CLIConnectionError) do
      client.connect
    end
  end

  test "client send message when not connected" do
    client = ClaudeAgent::Client.new

    assert_raises(ClaudeAgent::CLIConnectionError) do
      client.send_message("Hello")
    end
  end

  test "client query alias" do
    transport = MockTransport.new
    client = ClaudeAgent::Client.new(transport: transport)
    client.connect

    assert client.respond_to?(:query)
    assert_equal client.method(:send_message), client.method(:query)
  end

  test "client receive methods when not connected" do
    client = ClaudeAgent::Client.new

    assert_raises(ClaudeAgent::CLIConnectionError) do
      client.receive_messages.to_a
    end

    assert_raises(ClaudeAgent::CLIConnectionError) do
      client.receive_response.to_a
    end
  end

  test "client interrupt when not connected" do
    client = ClaudeAgent::Client.new

    assert_raises(ClaudeAgent::CLIConnectionError) do
      client.interrupt
    end
  end

  test "client set permission mode when not connected" do
    client = ClaudeAgent::Client.new

    assert_raises(ClaudeAgent::CLIConnectionError) do
      client.set_permission_mode("acceptEdits")
    end
  end

  test "client set model when not connected" do
    client = ClaudeAgent::Client.new

    assert_raises(ClaudeAgent::CLIConnectionError) do
      client.set_model("claude-sonnet-4-5-20250514")
    end
  end

  test "client rewind files when not connected" do
    client = ClaudeAgent::Client.new

    assert_raises(ClaudeAgent::CLIConnectionError) do
      client.rewind_files("msg-123")
    end
  end

  test "client open block" do
    transport = MockTransport.new
    connected_inside = false

    ClaudeAgent::Client.open(transport: transport) do |client|
      connected_inside = client.connected?
    end

    assert connected_inside
    refute transport.connected?
  end

  test "client open with prompt" do
    transport = MockTransport.new(responses: [])

    ClaudeAgent::Client.open(transport: transport, prompt: "Hello!") do |client|
      user_messages = transport.written_messages.select { |m| m["type"] == "user" }
      assert_equal 1, user_messages.length
      assert_equal "Hello!", user_messages.first["message"]["content"]
    end
  end
end
