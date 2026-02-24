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

  test "client stop task when not connected" do
    client = ClaudeAgent::Client.new

    assert_raises(ClaudeAgent::CLIConnectionError) do
      client.stop_task("task-123")
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

  # --- Turn Result ---

  test "receive_turn returns TurnResult" do
    transport = MockTransport.new
    client = ClaudeAgent::Client.new(transport: transport)
    client.connect

    transport.add_response({
      "type" => "assistant",
      "message" => { "role" => "assistant", "content" => [ { "type" => "text", "text" => "Hello!" } ], "model" => "claude" }
    })
    transport.add_response({
      "type" => "result",
      "subtype" => "success",
      "duration_ms" => 1000,
      "duration_api_ms" => 800,
      "is_error" => false,
      "num_turns" => 1,
      "session_id" => "session-abc",
      "total_cost_usd" => 0.01,
      "usage" => { "input_tokens" => 100, "output_tokens" => 50 }
    })

    turn = client.receive_turn

    assert_instance_of ClaudeAgent::TurnResult, turn
    assert turn.complete?
    assert turn.success?
    assert_equal "Hello!", turn.text
    assert_equal 0.01, turn.cost
    assert_equal 100, turn.usage[:input_tokens]
  end

  test "receive_turn yields messages" do
    transport = MockTransport.new
    client = ClaudeAgent::Client.new(transport: transport)
    client.connect

    transport.add_response({
      "type" => "assistant",
      "message" => { "role" => "assistant", "content" => [ { "type" => "text", "text" => "Hi" } ], "model" => "claude" }
    })
    transport.add_response({
      "type" => "result",
      "subtype" => "success",
      "duration_ms" => 500,
      "duration_api_ms" => 400,
      "is_error" => false,
      "num_turns" => 1,
      "session_id" => "session-abc"
    })

    yielded = []
    turn = client.receive_turn { |msg| yielded << msg }

    assert_equal 2, yielded.size
    assert_instance_of ClaudeAgent::AssistantMessage, yielded[0]
    assert_instance_of ClaudeAgent::ResultMessage, yielded[1]
    assert_equal "Hi", turn.text
  end

  test "receive_turn tracks cumulative_usage" do
    transport = MockTransport.new
    client = ClaudeAgent::Client.new(transport: transport)
    client.connect

    transport.add_response({
      "type" => "result",
      "subtype" => "success",
      "duration_ms" => 500,
      "duration_api_ms" => 400,
      "is_error" => false,
      "num_turns" => 1,
      "session_id" => "session-abc",
      "total_cost_usd" => 0.02,
      "usage" => { "input_tokens" => 200, "output_tokens" => 100 }
    })

    client.receive_turn

    assert_equal 200, client.cumulative_usage.input_tokens
    assert_equal 100, client.cumulative_usage.output_tokens
  end

  test "send_and_receive returns TurnResult" do
    transport = MockTransport.new
    client = ClaudeAgent::Client.new(transport: transport)
    client.connect

    transport.add_response({
      "type" => "assistant",
      "message" => { "role" => "assistant", "content" => [ { "type" => "text", "text" => "Done!" } ], "model" => "claude" }
    })
    transport.add_response({
      "type" => "result",
      "subtype" => "success",
      "duration_ms" => 1000,
      "duration_api_ms" => 800,
      "is_error" => false,
      "num_turns" => 1,
      "session_id" => "session-abc",
      "total_cost_usd" => 0.03
    })

    turn = client.send_and_receive("Fix the bug")

    assert_instance_of ClaudeAgent::TurnResult, turn
    assert_equal "Done!", turn.text
    assert_equal 0.03, turn.cost

    # Verify message was sent
    user_messages = transport.written_messages.select { |m| m["type"] == "user" }
    assert_equal 1, user_messages.size
    assert_equal "Fix the bug", user_messages.first["message"]["content"]
  end

  test "send_and_receive yields messages" do
    transport = MockTransport.new
    client = ClaudeAgent::Client.new(transport: transport)
    client.connect

    transport.add_response({
      "type" => "assistant",
      "message" => { "role" => "assistant", "content" => [ { "type" => "text", "text" => "Hi" } ], "model" => "claude" }
    })
    transport.add_response({
      "type" => "result",
      "subtype" => "success",
      "duration_ms" => 500,
      "duration_api_ms" => 400,
      "is_error" => false,
      "num_turns" => 1,
      "session_id" => "session-abc"
    })

    yielded = []
    turn = client.send_and_receive("Hello") { |msg| yielded << msg }

    assert_equal 2, yielded.size
    assert_equal "Hi", turn.text
  end

  test "send_and_receive when not connected raises" do
    client = ClaudeAgent::Client.new

    assert_raises(ClaudeAgent::CLIConnectionError) do
      client.send_and_receive("Hello")
    end
  end

  test "receive_turn when not connected raises" do
    client = ClaudeAgent::Client.new

    assert_raises(ClaudeAgent::CLIConnectionError) do
      client.receive_turn
    end
  end

  # --- Cumulative Usage ---

  test "client has cumulative_usage" do
    client = ClaudeAgent::Client.new
    assert_instance_of ClaudeAgent::CumulativeUsage, client.cumulative_usage
    assert_equal 0, client.cumulative_usage.input_tokens
  end

  test "cumulative_usage tracks across receive_response with block" do
    transport = MockTransport.new
    client = ClaudeAgent::Client.new(transport: transport)
    client.connect

    transport.add_response({
      "type" => "assistant",
      "message" => { "role" => "assistant", "content" => [ { "type" => "text", "text" => "Hi" } ], "model" => "claude" }
    })
    transport.add_response({
      "type" => "result",
      "subtype" => "success",
      "duration_ms" => 1000,
      "duration_api_ms" => 800,
      "is_error" => false,
      "num_turns" => 1,
      "session_id" => "session-abc",
      "total_cost_usd" => 0.01,
      "usage" => { "input_tokens" => 100, "output_tokens" => 50 }
    })

    client.receive_response { |_| }

    assert_equal 100, client.cumulative_usage.input_tokens
    assert_equal 50, client.cumulative_usage.output_tokens
    assert_equal 0.01, client.cumulative_usage.total_cost_usd
    assert_equal 1, client.cumulative_usage.num_turns
  end

  test "cumulative_usage tracks via enumerator" do
    transport = MockTransport.new
    client = ClaudeAgent::Client.new(transport: transport)
    client.connect

    transport.add_response({
      "type" => "result",
      "subtype" => "success",
      "duration_ms" => 500,
      "duration_api_ms" => 400,
      "is_error" => false,
      "num_turns" => 1,
      "session_id" => "session-abc",
      "total_cost_usd" => 0.02,
      "usage" => { "input_tokens" => 200, "output_tokens" => 100 }
    })

    client.receive_response.each { |_| }

    assert_equal 200, client.cumulative_usage.input_tokens
    assert_equal 100, client.cumulative_usage.output_tokens
    assert_equal 0.02, client.cumulative_usage.total_cost_usd
  end
end
