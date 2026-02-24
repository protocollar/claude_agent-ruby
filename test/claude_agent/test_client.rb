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

  # --- Event Handler ---

  test "client has event_handler" do
    client = ClaudeAgent::Client.new
    assert_instance_of ClaudeAgent::EventHandler, client.event_handler
  end

  test "on returns self for chaining" do
    client = ClaudeAgent::Client.new
    result = client.on(:text) { |_| }
    assert_equal client, result
  end

  test "on_text convenience method" do
    client = ClaudeAgent::Client.new
    result = client.on_text { |_| }
    assert_equal client, result
  end

  test "events fire during receive_turn" do
    transport = MockTransport.new
    client = ClaudeAgent::Client.new(transport: transport)
    client.connect

    texts = []
    tools = []
    results = []
    client.on_text { |text| texts << text }
    client.on_tool_use { |tool| tools << tool }
    client.on_result { |r| results << r }

    transport.add_response({
      "type" => "assistant",
      "message" => {
        "role" => "assistant",
        "content" => [
          { "type" => "text", "text" => "Let me read that." },
          { "type" => "tool_use", "id" => "t1", "name" => "Read", "input" => { "file_path" => "/tmp/file" } }
        ],
        "model" => "claude"
      }
    })
    transport.add_response({
      "type" => "result",
      "subtype" => "success",
      "duration_ms" => 1000,
      "duration_api_ms" => 800,
      "is_error" => false,
      "num_turns" => 1,
      "session_id" => "session-abc",
      "total_cost_usd" => 0.01
    })

    turn = client.receive_turn

    assert_equal [ "Let me read that." ], texts
    assert_equal 1, tools.size
    assert_equal "Read", tools[0].name
    assert_equal 1, results.size
    assert_equal 0.01, results[0].total_cost_usd
    assert_equal "Let me read that.", turn.text
  end

  test "events fire during send_and_receive" do
    transport = MockTransport.new
    client = ClaudeAgent::Client.new(transport: transport)
    client.connect

    texts = []
    client.on_text { |text| texts << text }

    transport.add_response({
      "type" => "assistant",
      "message" => { "role" => "assistant", "content" => [ { "type" => "text", "text" => "Done!" } ], "model" => "claude" }
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

    client.send_and_receive("Fix the bug")

    assert_equal [ "Done!" ], texts
  end

  test "events fire alongside block in receive_turn" do
    transport = MockTransport.new
    client = ClaudeAgent::Client.new(transport: transport)
    client.connect

    event_texts = []
    block_messages = []
    client.on_text { |text| event_texts << text }

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

    client.receive_turn { |msg| block_messages << msg }

    assert_equal [ "Hi" ], event_texts
    assert_equal 2, block_messages.size
  end

  test "events persist across turns" do
    transport = MockTransport.new
    client = ClaudeAgent::Client.new(transport: transport)
    client.connect

    texts = []
    client.on_text { |text| texts << text }

    # Turn 1
    transport.add_response({
      "type" => "assistant",
      "message" => { "role" => "assistant", "content" => [ { "type" => "text", "text" => "Turn 1" } ], "model" => "claude" }
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
    client.receive_turn

    # Turn 2
    transport.add_response({
      "type" => "assistant",
      "message" => { "role" => "assistant", "content" => [ { "type" => "text", "text" => "Turn 2" } ], "model" => "claude" }
    })
    transport.add_response({
      "type" => "result",
      "subtype" => "success",
      "duration_ms" => 500,
      "duration_api_ms" => 400,
      "is_error" => false,
      "num_turns" => 2,
      "session_id" => "session-abc"
    })
    client.receive_turn

    assert_equal [ "Turn 1", "Turn 2" ], texts
  end

  test "tool_result event pairs across messages" do
    transport = MockTransport.new
    client = ClaudeAgent::Client.new(transport: transport)
    client.connect

    tool_results = []
    client.on_tool_result { |result, tool_use| tool_results << { result: result, tool_use: tool_use } }

    transport.add_response({
      "type" => "assistant",
      "message" => {
        "role" => "assistant",
        "content" => [
          { "type" => "tool_use", "id" => "t1", "name" => "Read", "input" => { "file_path" => "/tmp/file" } }
        ],
        "model" => "claude"
      }
    })
    transport.add_response({
      "type" => "user",
      "message" => {
        "role" => "user",
        "content" => [
          { "type" => "tool_result", "tool_use_id" => "t1", "content" => "file data" }
        ]
      }
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

    client.receive_turn

    assert_equal 1, tool_results.size
    assert_equal "file data", tool_results[0][:result].content
    assert_equal "Read", tool_results[0][:tool_use].name
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
