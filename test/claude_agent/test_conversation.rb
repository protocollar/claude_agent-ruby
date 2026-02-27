# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentConversation < ActiveSupport::TestCase
  # --- Helper: build a connected conversation with MockTransport ---

  def build_conversation(transport: nil, **kwargs)
    transport ||= MockTransport.new
    client = ClaudeAgent::Client.new(transport: transport)
    ClaudeAgent::Conversation.new(client: client, **kwargs)
  end

  def result_response(session_id: "session-abc", cost: 0.01, num_turns: 1)
    {
      "type" => "result",
      "subtype" => "success",
      "duration_ms" => 1000,
      "duration_api_ms" => 800,
      "is_error" => false,
      "num_turns" => num_turns,
      "session_id" => session_id,
      "total_cost_usd" => cost,
      "usage" => { "input_tokens" => 100, "output_tokens" => 50 }
    }
  end

  def assistant_response(text: "Hello!", tool_use: nil)
    content = [ { "type" => "text", "text" => text } ]
    if tool_use
      content << { "type" => "tool_use", "id" => tool_use[:id], "name" => tool_use[:name], "input" => tool_use[:input] }
    end
    {
      "type" => "assistant",
      "message" => { "role" => "assistant", "content" => content, "model" => "claude" }
    }
  end

  def tool_result_response(tool_use_id:, content: "file data", is_error: false)
    {
      "type" => "user",
      "message" => {
        "role" => "user",
        "content" => [
          { "type" => "tool_result", "tool_use_id" => tool_use_id, "content" => content, "is_error" => is_error }
        ]
      }
    }
  end

  # --- Initialization ---

  test "initializes with defaults" do
    conversation = build_conversation
    assert_equal [], conversation.turns
    assert_equal [], conversation.messages
    assert_equal [], conversation.tool_activity
    refute conversation.open?
    refute conversation.closed?
  end

  test "initializes with pre-built client" do
    transport = MockTransport.new
    client = ClaudeAgent::Client.new(transport: transport)
    conversation = ClaudeAgent::Conversation.new(client: client)

    assert_equal client, conversation.client
  end

  test "initializes with options kwargs" do
    conversation = build_conversation(model: "claude-sonnet-4-5-20250514")
    # Options kwargs pass through — no error means they were accepted
    assert_instance_of ClaudeAgent::Client, conversation.client
  end

  # --- Lifecycle ---

  test "auto-connects on first say" do
    transport = MockTransport.new
    conversation = build_conversation(transport: transport)

    transport.add_response(assistant_response)
    transport.add_response(result_response)

    refute conversation.open?
    conversation.say("Hello")
    assert conversation.open?
  end

  test "close disconnects" do
    transport = MockTransport.new
    conversation = build_conversation(transport: transport)

    transport.add_response(assistant_response)
    transport.add_response(result_response)
    conversation.say("Hello")

    assert conversation.open?
    conversation.close
    assert conversation.closed?
    refute conversation.open?
  end

  test "close is idempotent" do
    transport = MockTransport.new
    conversation = build_conversation(transport: transport)

    transport.add_response(assistant_response)
    transport.add_response(result_response)
    conversation.say("Hello")

    conversation.close
    conversation.close # should not raise
    assert conversation.closed?
  end

  test "say raises after close" do
    transport = MockTransport.new
    conversation = build_conversation(transport: transport)

    transport.add_response(assistant_response)
    transport.add_response(result_response)
    conversation.say("Hello")
    conversation.close

    assert_raises(ClaudeAgent::Error) do
      conversation.say("Should fail")
    end
  end

  # --- Say ---

  test "say returns TurnResult" do
    transport = MockTransport.new
    conversation = build_conversation(transport: transport)

    transport.add_response(assistant_response(text: "Done!"))
    transport.add_response(result_response)

    turn = conversation.say("Fix the bug")

    assert_instance_of ClaudeAgent::TurnResult, turn
    assert_equal "Done!", turn.text
    assert turn.complete?
  end

  test "say accumulates turns" do
    transport = MockTransport.new
    conversation = build_conversation(transport: transport)

    # Turn 1
    transport.add_response(assistant_response(text: "Turn 1"))
    transport.add_response(result_response(num_turns: 1))
    conversation.say("First")

    # Turn 2
    transport.add_response(assistant_response(text: "Turn 2"))
    transport.add_response(result_response(num_turns: 2))
    conversation.say("Second")

    assert_equal 2, conversation.turns.size
    assert_equal "Turn 1", conversation.turns[0].text
    assert_equal "Turn 2", conversation.turns[1].text
  end

  test "say accumulates messages" do
    transport = MockTransport.new
    conversation = build_conversation(transport: transport)

    transport.add_response(assistant_response)
    transport.add_response(result_response)
    conversation.say("Hello")

    assert_equal 2, conversation.messages.size
    assert_instance_of ClaudeAgent::AssistantMessage, conversation.messages[0]
    assert_instance_of ClaudeAgent::ResultMessage, conversation.messages[1]
  end

  test "say yields messages" do
    transport = MockTransport.new
    conversation = build_conversation(transport: transport)

    transport.add_response(assistant_response)
    transport.add_response(result_response)

    yielded = []
    conversation.say("Hello") { |msg| yielded << msg }

    assert_equal 2, yielded.size
  end

  # --- Tool Activity ---

  test "builds tool activity from turn" do
    transport = MockTransport.new
    conversation = build_conversation(transport: transport)

    transport.add_response(assistant_response(
      text: "Let me read that.",
      tool_use: { id: "t1", name: "Read", input: { "file_path" => "/tmp/test.rb" } }
    ))
    transport.add_response(tool_result_response(tool_use_id: "t1"))
    transport.add_response(result_response)

    conversation.say("Read the file")

    assert_equal 1, conversation.tool_activity.size
    activity = conversation.tool_activity.first
    assert_instance_of ClaudeAgent::ToolActivity, activity
    assert_equal "Read", activity.name
    assert_equal "t1", activity.id
    assert_equal 0, activity.turn_index
    assert activity.complete?
    refute activity.error?
  end

  test "tool activity across multiple turns" do
    transport = MockTransport.new
    conversation = build_conversation(transport: transport)

    # Turn 0
    transport.add_response(assistant_response(
      text: "Reading.",
      tool_use: { id: "t1", name: "Read", input: { "file_path" => "/a.rb" } }
    ))
    transport.add_response(tool_result_response(tool_use_id: "t1"))
    transport.add_response(result_response)
    conversation.say("Read a.rb")

    # Turn 1
    transport.add_response(assistant_response(
      text: "Writing.",
      tool_use: { id: "t2", name: "Write", input: { "file_path" => "/b.rb", "content" => "hello" } }
    ))
    transport.add_response(tool_result_response(tool_use_id: "t2"))
    transport.add_response(result_response)
    conversation.say("Write b.rb")

    assert_equal 2, conversation.tool_activity.size
    assert_equal 0, conversation.tool_activity[0].turn_index
    assert_equal 1, conversation.tool_activity[1].turn_index
    assert_equal "Read", conversation.tool_activity[0].name
    assert_equal "Write", conversation.tool_activity[1].name
  end

  test "tool activity with error result" do
    transport = MockTransport.new
    conversation = build_conversation(transport: transport)

    transport.add_response(assistant_response(
      text: "Trying.",
      tool_use: { id: "t1", name: "Bash", input: { "command" => "rm -rf /" } }
    ))
    transport.add_response(tool_result_response(tool_use_id: "t1", content: "Permission denied", is_error: true))
    transport.add_response(result_response)

    conversation.say("Run command")

    activity = conversation.tool_activity.first
    assert activity.complete?
    assert activity.error?
  end

  # --- Callbacks ---

  test "on_text callback fires" do
    transport = MockTransport.new
    texts = []
    conversation = build_conversation(transport: transport, on_text: ->(text) { texts << text })

    transport.add_response(assistant_response(text: "Hello!"))
    transport.add_response(result_response)
    conversation.say("Hi")

    assert_equal [ "Hello!" ], texts
  end

  test "on_stream alias for on_text" do
    transport = MockTransport.new
    texts = []
    conversation = build_conversation(transport: transport, on_stream: ->(text) { texts << text })

    transport.add_response(assistant_response(text: "Streamed!"))
    transport.add_response(result_response)
    conversation.say("Hi")

    assert_equal [ "Streamed!" ], texts
  end

  test "on_tool_use callback fires" do
    transport = MockTransport.new
    tools = []
    conversation = build_conversation(transport: transport, on_tool_use: ->(tool) { tools << tool })

    transport.add_response(assistant_response(
      text: "Reading.",
      tool_use: { id: "t1", name: "Read", input: { "file_path" => "/tmp/file" } }
    ))
    transport.add_response(tool_result_response(tool_use_id: "t1"))
    transport.add_response(result_response)

    conversation.say("Read file")

    assert_equal 1, tools.size
    assert_equal "Read", tools[0].name
  end

  test "on_tool_result callback fires" do
    transport = MockTransport.new
    results = []
    conversation = build_conversation(transport: transport, on_tool_result: ->(result, _tool_use) { results << result })

    transport.add_response(assistant_response(
      text: "Reading.",
      tool_use: { id: "t1", name: "Read", input: { "file_path" => "/tmp/file" } }
    ))
    transport.add_response(tool_result_response(tool_use_id: "t1", content: "data"))
    transport.add_response(result_response)

    conversation.say("Read file")

    assert_equal 1, results.size
    assert_equal "data", results[0].content
  end

  test "on_result callback fires" do
    transport = MockTransport.new
    results = []
    conversation = build_conversation(transport: transport, on_result: ->(r) { results << r })

    transport.add_response(assistant_response)
    transport.add_response(result_response(cost: 0.05))
    conversation.say("Hi")

    assert_equal 1, results.size
    assert_equal 0.05, results[0].total_cost_usd
  end

  test "on_message callback fires for every message" do
    transport = MockTransport.new
    messages = []
    conversation = build_conversation(transport: transport, on_message: ->(msg) { messages << msg })

    transport.add_response(assistant_response)
    transport.add_response(result_response)
    conversation.say("Hi")

    assert_equal 2, messages.size
  end

  test "on_stream_event callback fires for StreamEvent" do
    transport = MockTransport.new
    events = []
    conversation = build_conversation(
      transport: transport,
      on_stream_event: ->(evt) { events << evt }
    )

    transport.add_response({
      "type" => "stream_event",
      "uuid" => "e1",
      "session_id" => "s1",
      "event" => { "type" => "content_block_delta" }
    })
    transport.add_response(assistant_response)
    transport.add_response(result_response)
    conversation.say("Hi")

    assert_equal 1, events.size
    assert_instance_of ClaudeAgent::StreamEvent, events[0]
  end

  test "on_status callback fires for StatusMessage" do
    transport = MockTransport.new
    statuses = []
    conversation = build_conversation(
      transport: transport,
      on_status: ->(msg) { statuses << msg }
    )

    transport.add_response({
      "type" => "system",
      "subtype" => "status",
      "uuid" => "m1",
      "session_id" => "s1",
      "status" => "compacting"
    })
    transport.add_response(assistant_response)
    transport.add_response(result_response)
    conversation.say("Hi")

    assert_equal 1, statuses.size
    assert_instance_of ClaudeAgent::StatusMessage, statuses[0]
  end

  test "on_assistant callback fires for AssistantMessage" do
    transport = MockTransport.new
    assistants = []
    conversation = build_conversation(
      transport: transport,
      on_assistant: ->(msg) { assistants << msg }
    )

    transport.add_response(assistant_response(text: "Hello!"))
    transport.add_response(result_response)
    conversation.say("Hi")

    assert_equal 1, assistants.size
    assert_instance_of ClaudeAgent::AssistantMessage, assistants[0]
  end

  test "callbacks persist across turns" do
    transport = MockTransport.new
    texts = []
    conversation = build_conversation(transport: transport, on_text: ->(text) { texts << text })

    transport.add_response(assistant_response(text: "One"))
    transport.add_response(result_response)
    conversation.say("First")

    transport.add_response(assistant_response(text: "Two"))
    transport.add_response(result_response)
    conversation.say("Second")

    assert_equal [ "One", "Two" ], texts
  end

  # --- Cost & Usage ---

  test "total_cost reflects session-cumulative value from CLI" do
    transport = MockTransport.new
    conversation = build_conversation(transport: transport)

    transport.add_response(assistant_response)
    transport.add_response(result_response(cost: 0.01))
    conversation.say("First")

    # CLI sends cumulative cost, not per-turn delta
    transport.add_response(assistant_response)
    transport.add_response(result_response(cost: 0.03))
    conversation.say("Second")

    assert_equal 0.03, conversation.total_cost
  end

  test "usage returns cumulative_usage" do
    transport = MockTransport.new
    conversation = build_conversation(transport: transport)

    transport.add_response(assistant_response)
    transport.add_response(result_response)
    conversation.say("Hello")

    assert_instance_of ClaudeAgent::CumulativeUsage, conversation.usage
    assert_equal 100, conversation.usage.input_tokens
    assert_equal 50, conversation.usage.output_tokens
  end

  # --- Session ---

  test "session_id from latest turn" do
    transport = MockTransport.new
    conversation = build_conversation(transport: transport)

    assert_nil conversation.session_id

    transport.add_response(assistant_response)
    transport.add_response(result_response(session_id: "session-xyz"))
    conversation.say("Hello")

    assert_equal "session-xyz", conversation.session_id
  end

  # --- Permission Queue ---

  test "pending_permission delegates to client" do
    conversation = build_conversation
    assert_nil conversation.pending_permission
  end

  test "pending_permissions? delegates to client" do
    conversation = build_conversation
    refute conversation.pending_permissions?
  end

  # --- Block Form ---

  test "open block form auto-closes" do
    transport = MockTransport.new
    client = ClaudeAgent::Client.new(transport: transport)
    conversation_ref = nil

    ClaudeAgent::Conversation.open(client: client) do |conversation|
      conversation_ref = conversation
      transport.add_response(assistant_response)
      transport.add_response(result_response)
      conversation.say("Hello")
      assert conversation.open?
    end

    assert conversation_ref.closed?
  end

  test "open block form closes on error" do
    transport = MockTransport.new
    client = ClaudeAgent::Client.new(transport: transport)
    conversation_ref = nil

    assert_raises(RuntimeError) do
      ClaudeAgent::Conversation.open(client: client) do |conversation|
        conversation_ref = conversation
        transport.add_response(assistant_response)
        transport.add_response(result_response)
        conversation.say("Hello")
        raise "boom"
      end
    end

    assert conversation_ref.closed?
  end

  # --- Resume ---

  test "resume creates with resume option" do
    transport = MockTransport.new
    client = ClaudeAgent::Client.new(transport: transport)
    conversation = ClaudeAgent::Conversation.resume("session-abc", client: client)

    assert_instance_of ClaudeAgent::Conversation, conversation
  end

  # --- Inspect ---

  test "inspect includes turn count" do
    transport = MockTransport.new
    conversation = build_conversation(transport: transport)

    transport.add_response(assistant_response)
    transport.add_response(result_response)
    conversation.say("Hello")

    output = conversation.inspect
    assert_includes output, "turns=1"
    assert_includes output, "messages=2"
  end

  test "inspect shows pending state before connection" do
    conversation = build_conversation
    assert_includes conversation.inspect, "pending"
  end

  test "inspect shows open state" do
    transport = MockTransport.new
    conversation = build_conversation(transport: transport)

    transport.add_response(assistant_response)
    transport.add_response(result_response)
    conversation.say("Hello")

    assert_includes conversation.inspect, "open"
  end

  test "inspect shows closed state" do
    transport = MockTransport.new
    conversation = build_conversation(transport: transport)

    transport.add_response(assistant_response)
    transport.add_response(result_response)
    conversation.say("Hello")
    conversation.close

    assert_includes conversation.inspect, "closed"
  end

  # --- Module-level convenience ---

  test "ClaudeAgent.conversation creates Conversation" do
    transport = MockTransport.new
    client = ClaudeAgent::Client.new(transport: transport)
    conversation = ClaudeAgent.conversation(client: client)
    assert_instance_of ClaudeAgent::Conversation, conversation
  end

  test "ClaudeAgent.resume_conversation creates Conversation" do
    transport = MockTransport.new
    client = ClaudeAgent::Client.new(transport: transport)
    conversation = ClaudeAgent.resume_conversation("session-abc", client: client)
    assert_instance_of ClaudeAgent::Conversation, conversation
  end

  # --- Tool Tracker ---

  test "tool_tracker is nil by default" do
    conversation = build_conversation
    assert_nil conversation.tool_tracker
  end

  test "track_tools true creates a tracker" do
    conversation = build_conversation(track_tools: true)
    assert_instance_of ClaudeAgent::ToolActivityTracker, conversation.tool_tracker
  end

  test "tracker resets between turns" do
    transport = MockTransport.new
    conversation = build_conversation(transport: transport, track_tools: true)

    # Turn 1 with a tool
    transport.add_response(assistant_response(
      text: "Reading.",
      tool_use: { id: "t1", name: "Read", input: { "file_path" => "/a.rb" } }
    ))
    transport.add_response(tool_result_response(tool_use_id: "t1"))
    transport.add_response(result_response)
    conversation.say("Read a.rb")

    # After turn completes, tracker should be reset
    assert conversation.tool_tracker.empty?

    # Turn 2 with a different tool
    transport.add_response(assistant_response(
      text: "Writing.",
      tool_use: { id: "t2", name: "Write", input: { "file_path" => "/b.rb", "content" => "hello" } }
    ))
    transport.add_response(tool_result_response(tool_use_id: "t2"))
    transport.add_response(result_response)
    conversation.say("Write b.rb")

    # After second turn, tracker is reset again
    assert conversation.tool_tracker.empty?
  end

  # --- on_permission ---

  test "on_permission queue mode is default" do
    transport = MockTransport.new
    client = ClaudeAgent::Client.new(transport: transport)
    conversation = ClaudeAgent::Conversation.new(client: client)

    # Queue mode is the default — should not raise
    assert_instance_of ClaudeAgent::Conversation, conversation
  end

  test "on_permission with callable sets can_use_tool" do
    transport = MockTransport.new
    handler = ->(_name, _input, _context) { ClaudeAgent::PermissionResultAllow.new }
    # Build without pre-built client so options get built internally
    conversation = ClaudeAgent::Conversation.new(
      on_permission: handler,
      permission_mode: "default"
    )

    assert_instance_of ClaudeAgent::Conversation, conversation
  end
end
