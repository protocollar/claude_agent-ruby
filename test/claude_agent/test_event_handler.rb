# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentEventHandler < ActiveSupport::TestCase
  setup do
    @handler = ClaudeAgent::EventHandler.new
  end

  # --- Registration ---

  test "on returns self for chaining" do
    result = @handler.on(:text) { |_| }
    assert_equal @handler, result
  end

  test "on_text returns self for chaining" do
    result = @handler.on_text { |_| }
    assert_equal @handler, result
  end

  test "has_handlers? false when empty" do
    refute @handler.has_handlers?
  end

  test "has_handlers? true after registration" do
    @handler.on_text { |_| }
    assert @handler.has_handlers?
  end

  test "chaining multiple handlers" do
    handler = ClaudeAgent::EventHandler.new
      .on_text { |_| }
      .on_result { |_| }
      .on_tool_use { |_| }

    assert handler.has_handlers?
  end

  # --- :message event ---

  test "on_message fires for every message type" do
    received = []
    @handler.on_message { |msg| received << msg }

    assistant = make_assistant("Hello")
    result = make_result
    user = ClaudeAgent::UserMessage.new(content: "Hi")

    @handler.handle(assistant)
    @handler.handle(user)
    @handler.handle(result)

    assert_equal 3, received.size
    assert_equal assistant, received[0]
    assert_equal user, received[1]
    assert_equal result, received[2]
  end

  # --- :text event ---

  test "on_text fires with assistant text" do
    texts = []
    @handler.on_text { |text| texts << text }

    @handler.handle(make_assistant("Hello, world!"))

    assert_equal [ "Hello, world!" ], texts
  end

  test "on_text fires for each assistant message" do
    texts = []
    @handler.on_text { |text| texts << text }

    @handler.handle(make_assistant("First"))
    @handler.handle(make_assistant("Second"))

    assert_equal [ "First", "Second" ], texts
  end

  test "on_text does not fire for empty text" do
    texts = []
    @handler.on_text { |text| texts << text }

    # Assistant message with only a tool use block, no text
    assistant = ClaudeAgent::AssistantMessage.new(
      content: [ ClaudeAgent::ToolUseBlock.new(id: "t1", name: "Read", input: {}) ],
      model: "claude"
    )
    @handler.handle(assistant)

    assert_empty texts
  end

  test "on_text does not fire for non-assistant messages" do
    texts = []
    @handler.on_text { |text| texts << text }

    @handler.handle(ClaudeAgent::UserMessage.new(content: "Hello"))
    @handler.handle(make_result)

    assert_empty texts
  end

  # --- :thinking event ---

  test "on_thinking fires with thinking content" do
    thoughts = []
    @handler.on_thinking { |t| thoughts << t }

    assistant = ClaudeAgent::AssistantMessage.new(
      content: [
        ClaudeAgent::ThinkingBlock.new(thinking: "Let me consider...", signature: "s1"),
        ClaudeAgent::TextBlock.new(text: "The answer is 4.")
      ],
      model: "claude"
    )
    @handler.handle(assistant)

    assert_equal [ "Let me consider..." ], thoughts
  end

  test "on_thinking does not fire when no thinking blocks" do
    thoughts = []
    @handler.on_thinking { |t| thoughts << t }

    @handler.handle(make_assistant("Just text"))

    assert_empty thoughts
  end

  # --- :tool_use event ---

  test "on_tool_use fires for each tool use block" do
    tools = []
    @handler.on_tool_use { |tool| tools << tool }

    assistant = ClaudeAgent::AssistantMessage.new(
      content: [
        ClaudeAgent::TextBlock.new(text: "Reading files"),
        ClaudeAgent::ToolUseBlock.new(id: "t1", name: "Read", input: { file_path: "/tmp/a.rb" }),
        ClaudeAgent::ToolUseBlock.new(id: "t2", name: "Read", input: { file_path: "/tmp/b.rb" })
      ],
      model: "claude"
    )
    @handler.handle(assistant)

    assert_equal 2, tools.size
    assert_equal "t1", tools[0].id
    assert_equal "t2", tools[1].id
  end

  test "on_tool_use fires for server tool use blocks" do
    tools = []
    @handler.on_tool_use { |tool| tools << tool }

    assistant = ClaudeAgent::AssistantMessage.new(
      content: [
        ClaudeAgent::ServerToolUseBlock.new(id: "st1", name: "query", input: {}, server_name: "db")
      ],
      model: "claude"
    )
    @handler.handle(assistant)

    assert_equal 1, tools.size
    assert_instance_of ClaudeAgent::ServerToolUseBlock, tools[0]
  end

  # --- :tool_result event ---

  test "on_tool_result fires with result and matched tool_use" do
    results = []
    @handler.on_tool_result { |result, tool_use| results << { result: result, tool_use: tool_use } }

    # First, a tool use
    assistant = ClaudeAgent::AssistantMessage.new(
      content: [ ClaudeAgent::ToolUseBlock.new(id: "t1", name: "Read", input: { file_path: "/tmp/file" }) ],
      model: "claude"
    )
    @handler.handle(assistant)

    # Then, the result
    user = ClaudeAgent::UserMessage.new(
      content: [ ClaudeAgent::ToolResultBlock.new(tool_use_id: "t1", content: "file data") ]
    )
    @handler.handle(user)

    assert_equal 1, results.size
    assert_equal "t1", results[0][:result].tool_use_id
    assert_equal "file data", results[0][:result].content
    assert_equal "t1", results[0][:tool_use].id
    assert_equal "Read", results[0][:tool_use].name
  end

  test "on_tool_result with nil tool_use when unmatched" do
    results = []
    @handler.on_tool_result { |result, tool_use| results << { result: result, tool_use: tool_use } }

    # Tool result without a preceding tool use
    user = ClaudeAgent::UserMessage.new(
      content: [ ClaudeAgent::ToolResultBlock.new(tool_use_id: "unknown", content: "data") ]
    )
    @handler.handle(user)

    assert_equal 1, results.size
    assert_nil results[0][:tool_use]
  end

  test "on_tool_result pairs server tool results" do
    results = []
    @handler.on_tool_result { |result, tool_use| results << { result: result, tool_use: tool_use } }

    assistant = ClaudeAgent::AssistantMessage.new(
      content: [ ClaudeAgent::ServerToolUseBlock.new(id: "st1", name: "query", input: {}, server_name: "db") ],
      model: "claude"
    )
    @handler.handle(assistant)

    user = ClaudeAgent::UserMessage.new(
      content: [ ClaudeAgent::ServerToolResultBlock.new(tool_use_id: "st1", content: "rows", server_name: "db") ]
    )
    @handler.handle(user)

    assert_equal 1, results.size
    assert_instance_of ClaudeAgent::ServerToolUseBlock, results[0][:tool_use]
  end

  test "on_tool_result ignores user messages with string content" do
    results = []
    @handler.on_tool_result { |result, _| results << result }

    @handler.handle(ClaudeAgent::UserMessage.new(content: "Hello"))

    assert_empty results
  end

  # --- :result event ---

  test "on_result fires for ResultMessage" do
    received = []
    @handler.on_result { |r| received << r }

    result = make_result(total_cost_usd: 0.05)
    @handler.handle(result)

    assert_equal 1, received.size
    assert_equal 0.05, received[0].total_cost_usd
  end

  test "on_result does not fire for other messages" do
    received = []
    @handler.on_result { |r| received << r }

    @handler.handle(make_assistant("Hello"))
    @handler.handle(ClaudeAgent::UserMessage.new(content: "Hi"))

    assert_empty received
  end

  # --- Multiple handlers for same event ---

  test "multiple handlers for same event all fire" do
    calls = []
    @handler.on_text { |text| calls << "handler1: #{text}" }
    @handler.on_text { |text| calls << "handler2: #{text}" }

    @handler.handle(make_assistant("Hi"))

    assert_equal [ "handler1: Hi", "handler2: Hi" ], calls
  end

  # --- reset! ---

  test "reset clears pending tool uses" do
    results = []
    @handler.on_tool_result { |_, tool_use| results << tool_use }

    # Register a tool use
    assistant = ClaudeAgent::AssistantMessage.new(
      content: [ ClaudeAgent::ToolUseBlock.new(id: "t1", name: "Read", input: {}) ],
      model: "claude"
    )
    @handler.handle(assistant)

    # Reset (simulating turn boundary)
    @handler.reset!

    # Now the result won't find a match
    user = ClaudeAgent::UserMessage.new(
      content: [ ClaudeAgent::ToolResultBlock.new(tool_use_id: "t1", content: "data") ]
    )
    @handler.handle(user)

    assert_equal 1, results.size
    assert_nil results[0]
  end

  # --- Generic on() ---

  test "on with symbol event" do
    texts = []
    @handler.on(:text) { |text| texts << text }

    @handler.handle(make_assistant("Hello"))

    assert_equal [ "Hello" ], texts
  end

  # --- Realistic multi-tool turn ---

  test "realistic turn dispatches all events in order" do
    log = []

    @handler.on_message { |msg| log << "message:#{msg.class.name.split("::").last}" }
    @handler.on_text { |text| log << "text:#{text}" }
    @handler.on_tool_use { |tool| log << "tool_use:#{tool.name}" }
    @handler.on_tool_result { |result, tool_use| log << "tool_result:#{tool_use&.name}:#{result.content}" }
    @handler.on_result { |r| log << "result:#{r.subtype}" }

    # Claude responds with text + tool use
    @handler.handle(ClaudeAgent::AssistantMessage.new(
      content: [
        ClaudeAgent::TextBlock.new(text: "Let me read that."),
        ClaudeAgent::ToolUseBlock.new(id: "t1", name: "Read", input: { file_path: "/tmp/file" })
      ],
      model: "claude"
    ))

    # Tool result
    @handler.handle(ClaudeAgent::UserMessage.new(
      content: [ ClaudeAgent::ToolResultBlock.new(tool_use_id: "t1", content: "file data") ]
    ))

    # Claude responds with final text
    @handler.handle(make_assistant("Done!"))

    # Result
    @handler.handle(make_result)

    expected = [
      "message:AssistantMessage",
      "text:Let me read that.",
      "tool_use:Read",
      "message:UserMessage",
      "tool_result:Read:file data",
      "message:AssistantMessage",
      "text:Done!",
      "message:ResultMessage",
      "result:success"
    ]
    assert_equal expected, log
  end

  # --- Type-based dispatch ---

  test "type-based dispatch fires for StreamEvent" do
    received = []
    @handler.on_stream_event { |msg| received << msg }

    event = ClaudeAgent::StreamEvent.new(
      uuid: "e1", session_id: "s1",
      event: { type: "content_block_delta" }
    )
    @handler.handle(event)

    assert_equal 1, received.size
    assert_instance_of ClaudeAgent::StreamEvent, received[0]
  end

  test "type-based dispatch fires for ToolProgressMessage" do
    received = []
    @handler.on_tool_progress { |msg| received << msg }

    progress = ClaudeAgent::ToolProgressMessage.new(
      uuid: "m1", session_id: "s1",
      tool_use_id: "t1", tool_name: "Bash",
      elapsed_time_seconds: 5.0
    )
    @handler.handle(progress)

    assert_equal 1, received.size
    assert_instance_of ClaudeAgent::ToolProgressMessage, received[0]
  end

  test "type-based dispatch fires for StatusMessage" do
    received = []
    @handler.on_status { |msg| received << msg }

    status = ClaudeAgent::StatusMessage.new(
      uuid: "m1", session_id: "s1", status: "compacting"
    )
    @handler.handle(status)

    assert_equal 1, received.size
    assert_instance_of ClaudeAgent::StatusMessage, received[0]
  end

  test "type-based dispatch fires :assistant for AssistantMessage" do
    received = []
    @handler.on_assistant { |msg| received << msg }

    @handler.handle(make_assistant("Hello"))

    assert_equal 1, received.size
    assert_instance_of ClaudeAgent::AssistantMessage, received[0]
  end

  test "type-based dispatch fires :user for UserMessage" do
    received = []
    @handler.on_user { |msg| received << msg }

    @handler.handle(ClaudeAgent::UserMessage.new(content: "Hello"))

    assert_equal 1, received.size
    assert_instance_of ClaudeAgent::UserMessage, received[0]
  end

  test "GenericMessage fires its dynamic type" do
    received = []
    @handler.on(:fancy_new_type) { |msg| received << msg }

    generic = ClaudeAgent::GenericMessage.new(
      message_type: "fancy_new_type",
      raw: { data: "hello" }
    )
    @handler.handle(generic)

    assert_equal 1, received.size
    assert_instance_of ClaudeAgent::GenericMessage, received[0]
  end

  test "all three layers fire in order: message, type, decomposed" do
    log = []

    @handler.on_message { |_| log << :message }
    @handler.on_assistant { |_| log << :assistant }
    @handler.on_text { |_| log << :text }
    @handler.on_tool_use { |_| log << :tool_use }

    @handler.handle(ClaudeAgent::AssistantMessage.new(
      content: [
        ClaudeAgent::TextBlock.new(text: "Hello"),
        ClaudeAgent::ToolUseBlock.new(id: "t1", name: "Read", input: {})
      ],
      model: "claude"
    ))

    assert_equal [ :message, :assistant, :text, :tool_use ], log
  end

  test "result fires via type-based dispatch" do
    log = []

    @handler.on_message { |_| log << :message }
    @handler.on_result { |_| log << :result }

    @handler.handle(make_result)

    assert_equal [ :message, :result ], log
  end

  test "type-based dispatch fires for ElicitationCompleteMessage" do
    received = []
    @handler.on_elicitation_complete { |msg| received << msg }

    msg = ClaudeAgent::ElicitationCompleteMessage.new(
      uuid: "e1", session_id: "s1",
      mcp_server_name: "test-server", elicitation_id: "elicit-1"
    )
    @handler.handle(msg)

    assert_equal 1, received.size
    assert_instance_of ClaudeAgent::ElicitationCompleteMessage, received[0]
    assert_equal "test-server", received[0].mcp_server_name
  end

  test "type-based dispatch fires for LocalCommandOutputMessage" do
    received = []
    @handler.on_local_command_output { |msg| received << msg }

    msg = ClaudeAgent::LocalCommandOutputMessage.new(
      uuid: "l1", session_id: "s1", content: "command output"
    )
    @handler.handle(msg)

    assert_equal 1, received.size
    assert_instance_of ClaudeAgent::LocalCommandOutputMessage, received[0]
    assert_equal "command output", received[0].content
  end

  test "unknown event registration via on still works" do
    received = []
    @handler.on(:custom_event) { |data| received << data }

    # Custom events won't fire from handle() but direct emit works
    # Just verify registration doesn't blow up
    assert @handler.has_handlers?
  end

  # --- Handles non-dispatched message types gracefully ---

  test "handles stream events without error" do
    received = []
    @handler.on_message { |msg| received << msg }

    event = ClaudeAgent::StreamEvent.new(
      uuid: "e1", session_id: "s1",
      event: { type: "content_block_delta" }
    )
    @handler.handle(event)

    assert_equal 1, received.size
  end

  test "handles status messages without error" do
    received = []
    @handler.on_message { |msg| received << msg }

    status = ClaudeAgent::StatusMessage.new(
      uuid: "m1", session_id: "s1", status: "compacting"
    )
    @handler.handle(status)

    assert_equal 1, received.size
  end

  # --- Constants ---

  test "EVENTS includes all meta, type, and decomposed events" do
    assert_includes ClaudeAgent::EventHandler::EVENTS, :message
    assert_includes ClaudeAgent::EventHandler::EVENTS, :assistant
    assert_includes ClaudeAgent::EventHandler::EVENTS, :stream_event
    assert_includes ClaudeAgent::EventHandler::EVENTS, :text
    assert_includes ClaudeAgent::EventHandler::EVENTS, :tool_result
  end

  test "EVENTS is frozen" do
    assert ClaudeAgent::EventHandler::EVENTS.frozen?
  end

  private

  def make_assistant(text, model: "claude")
    ClaudeAgent::AssistantMessage.new(
      content: [ ClaudeAgent::TextBlock.new(text: text) ],
      model: model
    )
  end

  def make_result(
    subtype: "success",
    is_error: false,
    total_cost_usd: nil,
    duration_ms: 0,
    duration_api_ms: 0,
    session_id: "session-test",
    num_turns: 1
  )
    ClaudeAgent::ResultMessage.new(
      subtype: subtype,
      duration_ms: duration_ms,
      duration_api_ms: duration_api_ms,
      is_error: is_error,
      num_turns: num_turns,
      session_id: session_id,
      total_cost_usd: total_cost_usd
    )
  end
end
