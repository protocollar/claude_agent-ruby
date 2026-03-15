# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentTurnResult < ActiveSupport::TestCase
  setup do
    @turn = ClaudeAgent::TurnResult.new
  end

  # --- Initial State ---

  test "initial state" do
    assert_equal [], @turn.messages
    assert_nil @turn.result
    refute @turn.complete?
    refute @turn.success?
    refute @turn.error?
    assert_equal "", @turn.text
    assert_equal "", @turn.thinking
    assert_equal [], @turn.tool_uses
    assert_equal [], @turn.tool_results
    assert_equal [], @turn.tool_executions
    assert_nil @turn.usage
    assert_nil @turn.cost
    assert_nil @turn.duration_ms
    assert_nil @turn.session_id
    assert_nil @turn.model
    assert_equal [], @turn.permission_denials
    assert_equal [], @turn.errors
  end

  # --- Message Accumulation ---

  test "append returns self for chaining" do
    msg = make_assistant("Hello")
    assert_equal @turn, (@turn << msg)
  end

  test "accumulates messages" do
    @turn << make_assistant("Hello")
    @turn << make_result

    assert_equal 2, @turn.messages.size
  end

  # --- Text ---

  test "text from single assistant message" do
    @turn << make_assistant("Hello, world!")
    @turn << make_result

    assert_equal "Hello, world!", @turn.text
  end

  test "text concatenated across multiple assistant messages" do
    @turn << make_assistant("First part. ")
    @turn << make_assistant("Second part.")
    @turn << make_result

    assert_equal "First part. Second part.", @turn.text
  end

  test "text ignores non-text content blocks" do
    assistant = ClaudeAgent::AssistantMessage.new(
      content: [
        ClaudeAgent::TextBlock.new(text: "Let me read that"),
        ClaudeAgent::ToolUseBlock.new(id: "t1", name: "Read", input: { file_path: "/tmp/file" })
      ],
      model: "claude"
    )
    @turn << assistant
    @turn << make_result

    assert_equal "Let me read that", @turn.text
  end

  # --- Thinking ---

  test "thinking from single assistant message" do
    assistant = ClaudeAgent::AssistantMessage.new(
      content: [
        ClaudeAgent::ThinkingBlock.new(thinking: "Let me consider...", signature: "sig1"),
        ClaudeAgent::TextBlock.new(text: "The answer is 4.")
      ],
      model: "claude"
    )
    @turn << assistant
    @turn << make_result

    assert_equal "Let me consider...", @turn.thinking
  end

  test "thinking concatenated across messages" do
    @turn << ClaudeAgent::AssistantMessage.new(
      content: [ ClaudeAgent::ThinkingBlock.new(thinking: "Part 1. ", signature: "s1") ],
      model: "claude"
    )
    @turn << ClaudeAgent::AssistantMessage.new(
      content: [ ClaudeAgent::ThinkingBlock.new(thinking: "Part 2.", signature: "s2") ],
      model: "claude"
    )
    @turn << make_result

    assert_equal "Part 1. Part 2.", @turn.thinking
  end

  # --- Tool Uses ---

  test "tool_uses collects from all assistant messages" do
    @turn << ClaudeAgent::AssistantMessage.new(
      content: [
        ClaudeAgent::TextBlock.new(text: "Reading file"),
        ClaudeAgent::ToolUseBlock.new(id: "t1", name: "Read", input: { file_path: "/tmp/a.rb" })
      ],
      model: "claude"
    )
    @turn << make_user_with_tool_result("t1", "file contents")
    @turn << ClaudeAgent::AssistantMessage.new(
      content: [
        ClaudeAgent::TextBlock.new(text: "Writing file"),
        ClaudeAgent::ToolUseBlock.new(id: "t2", name: "Write", input: { file_path: "/tmp/b.rb", content: "new" })
      ],
      model: "claude"
    )
    @turn << make_result

    assert_equal 2, @turn.tool_uses.size
    assert_equal "Read", @turn.tool_uses[0].name
    assert_equal "Write", @turn.tool_uses[1].name
  end

  test "tool_uses includes server tool use blocks" do
    @turn << ClaudeAgent::AssistantMessage.new(
      content: [
        ClaudeAgent::ServerToolUseBlock.new(id: "st1", name: "query", input: { sql: "SELECT 1" }, server_name: "db")
      ],
      model: "claude"
    )
    @turn << make_result

    assert_equal 1, @turn.tool_uses.size
    assert_instance_of ClaudeAgent::ServerToolUseBlock, @turn.tool_uses[0]
  end

  # --- Tool Results ---

  test "tool_results collects from user messages" do
    @turn << ClaudeAgent::AssistantMessage.new(
      content: [ ClaudeAgent::ToolUseBlock.new(id: "t1", name: "Read", input: {}) ],
      model: "claude"
    )
    @turn << make_user_with_tool_result("t1", "file contents")
    @turn << make_result

    assert_equal 1, @turn.tool_results.size
    assert_equal "t1", @turn.tool_results[0].tool_use_id
    assert_equal "file contents", @turn.tool_results[0].content
  end

  test "tool_results skips user messages with string content" do
    @turn << ClaudeAgent::UserMessage.new(content: "Hello")
    @turn << make_result

    assert_equal [], @turn.tool_results
  end

  # --- Tool Executions ---

  test "tool_executions pairs tool uses with results" do
    @turn << ClaudeAgent::AssistantMessage.new(
      content: [
        ClaudeAgent::ToolUseBlock.new(id: "t1", name: "Read", input: { file_path: "/tmp/file" }),
        ClaudeAgent::ToolUseBlock.new(id: "t2", name: "Bash", input: { command: "ls" })
      ],
      model: "claude"
    )
    @turn << ClaudeAgent::UserMessage.new(
      content: [
        ClaudeAgent::ToolResultBlock.new(tool_use_id: "t1", content: "file data"),
        ClaudeAgent::ToolResultBlock.new(tool_use_id: "t2", content: "dir listing")
      ]
    )
    @turn << make_result

    execs = @turn.tool_executions
    assert_equal 2, execs.size

    assert_equal "t1", execs[0][:tool_use].id
    assert_equal "file data", execs[0][:tool_result].content

    assert_equal "t2", execs[1][:tool_use].id
    assert_equal "dir listing", execs[1][:tool_result].content
  end

  test "tool_executions with unmatched tool use" do
    @turn << ClaudeAgent::AssistantMessage.new(
      content: [ ClaudeAgent::ToolUseBlock.new(id: "t1", name: "Read", input: {}) ],
      model: "claude"
    )
    @turn << make_result

    execs = @turn.tool_executions
    assert_equal 1, execs.size
    assert_equal "t1", execs[0][:tool_use].id
    assert_nil execs[0][:tool_result]
  end

  # --- Result Accessors ---

  test "result accessors from ResultMessage" do
    @turn << make_assistant("Done")
    @turn << make_result(
      usage: { input_tokens: 100, output_tokens: 50 },
      total_cost_usd: 0.05,
      duration_ms: 1500,
      duration_api_ms: 1200,
      session_id: "session-abc",
      num_turns: 3,
      stop_reason: "end_turn"
    )

    assert_equal({ input_tokens: 100, output_tokens: 50 }, @turn.usage)
    assert_equal 0.05, @turn.cost
    assert_equal 1500, @turn.duration_ms
    assert_equal 1200, @turn.duration_api_ms
    assert_equal "session-abc", @turn.session_id
    assert_equal 3, @turn.num_turns
    assert_equal "end_turn", @turn.stop_reason
  end

  test "model from first assistant message" do
    @turn << ClaudeAgent::AssistantMessage.new(
      content: [ ClaudeAgent::TextBlock.new(text: "Hi") ],
      model: "claude-sonnet-4-5-20250514"
    )
    @turn << make_result

    assert_equal "claude-sonnet-4-5-20250514", @turn.model
  end

  test "model_usage from result" do
    model_usage = {
      "claude-sonnet" => { input_tokens: 100, output_tokens: 50, cost_usd: 0.01 }
    }
    @turn << make_result(model_usage: model_usage)

    assert_equal model_usage, @turn.model_usage
  end

  test "structured_output from result" do
    @turn << make_result(structured_output: { answer: 42 })

    assert_equal({ answer: 42 }, @turn.structured_output)
  end

  test "permission_denials from result" do
    denial = ClaudeAgent::SDKPermissionDenial.new(
      tool_name: "Write",
      tool_use_id: "t1",
      tool_input: { file_path: "/etc/passwd" }
    )
    @turn << make_result(permission_denials: [ denial ])

    assert_equal 1, @turn.permission_denials.size
    assert_equal "Write", @turn.permission_denials[0].tool_name
  end

  test "errors from result" do
    @turn << make_result(is_error: true, subtype: "error_max_turns", errors: [ "Maximum turns exceeded" ])

    assert_equal [ "Maximum turns exceeded" ], @turn.errors
  end

  # --- Status ---

  test "complete? after result" do
    refute @turn.complete?

    @turn << make_assistant("Hello")
    refute @turn.complete?

    @turn << make_result
    assert @turn.complete?
  end

  test "success? and error?" do
    @turn << make_result(is_error: false, subtype: "success")

    assert @turn.success?
    refute @turn.error?
  end

  test "error state" do
    @turn << make_result(is_error: true, subtype: "error_max_turns")

    refute @turn.success?
    assert @turn.error?
    assert_equal "error_max_turns", @turn.subtype
  end

  # --- Filtered Message Access ---

  test "assistant_messages" do
    @turn << make_assistant("First")
    @turn << ClaudeAgent::UserMessage.new(content: "ignored")
    @turn << make_assistant("Second")
    @turn << make_result

    assert_equal 2, @turn.assistant_messages.size
  end

  test "user_messages" do
    @turn << ClaudeAgent::UserMessage.new(content: "Hello")
    @turn << make_assistant("Hi")
    @turn << make_user_with_tool_result("t1", "result")
    @turn << make_result

    assert_equal 2, @turn.user_messages.size
  end

  test "stream_events" do
    @turn << ClaudeAgent::StreamEvent.new(
      uuid: "e1", session_id: "s1",
      event: { type: "content_block_delta", delta: { type: "text_delta", text: "Hi" } }
    )
    @turn << make_assistant("Hi")
    @turn << make_result

    assert_equal 1, @turn.stream_events.size
  end

  test "content_blocks across all assistant messages" do
    @turn << ClaudeAgent::AssistantMessage.new(
      content: [
        ClaudeAgent::TextBlock.new(text: "Hello"),
        ClaudeAgent::ToolUseBlock.new(id: "t1", name: "Read", input: {})
      ],
      model: "claude"
    )
    @turn << ClaudeAgent::AssistantMessage.new(
      content: [ ClaudeAgent::TextBlock.new(text: "World") ],
      model: "claude"
    )
    @turn << make_result

    blocks = @turn.content_blocks
    assert_equal 3, blocks.size
    assert_instance_of ClaudeAgent::TextBlock, blocks[0]
    assert_instance_of ClaudeAgent::ToolUseBlock, blocks[1]
    assert_instance_of ClaudeAgent::TextBlock, blocks[2]
  end

  # --- Streaming Text Fallback ---

  test "text falls back to streamed deltas when no assistant messages" do
    @turn << ClaudeAgent::StreamEvent.new(
      uuid: "e1", session_id: "s1",
      event: { type: "content_block_delta", delta: { type: "text_delta", text: "Hello " } }
    )
    @turn << ClaudeAgent::StreamEvent.new(
      uuid: "e2", session_id: "s1",
      event: { type: "content_block_delta", delta: { type: "text_delta", text: "world" } }
    )

    assert_equal "Hello world", @turn.text
  end

  test "text prefers assistant messages over streamed deltas" do
    @turn << ClaudeAgent::StreamEvent.new(
      uuid: "e1", session_id: "s1",
      event: { type: "content_block_delta", delta: { type: "text_delta", text: "Hello" } }
    )
    @turn << make_assistant("Hello")
    @turn << make_result

    assert_equal "Hello", @turn.text
  end

  test "text ignores non-text stream events" do
    @turn << ClaudeAgent::StreamEvent.new(
      uuid: "e1", session_id: "s1",
      event: { type: "content_block_delta", delta: { type: "thinking_delta", thinking: "hmm" } }
    )
    @turn << ClaudeAgent::StreamEvent.new(
      uuid: "e2", session_id: "s1",
      event: { type: "content_block_start", content_block: { type: "text" } }
    )

    assert_equal "", @turn.text
  end

  test "streamed text returns frozen string" do
    @turn << ClaudeAgent::StreamEvent.new(
      uuid: "e1", session_id: "s1",
      event: { type: "content_block_delta", delta: { type: "text_delta", text: "Hi" } }
    )

    assert @turn.text.frozen?
  end

  # --- Inspect ---

  test "inspect for incomplete turn" do
    result = @turn.inspect
    assert_match(/in_progress/, result)
    assert_match(/messages=0/, result)
  end

  test "inspect for successful turn" do
    @turn << make_assistant("Hello world")
    @turn << make_result(total_cost_usd: 0.05, duration_ms: 1500)

    result = @turn.inspect
    assert_match(/success/, result)
    assert_match(/messages=2/, result)
    assert_match(/text=11chars/, result)
    assert_match(/cost=\$0\.05/, result)
    assert_match(/duration=1500ms/, result)
  end

  test "inspect for error turn" do
    @turn << make_result(is_error: true, subtype: "error_max_turns")

    result = @turn.inspect
    assert_match(/error/, result)
  end

  test "inspect with tool uses" do
    @turn << ClaudeAgent::AssistantMessage.new(
      content: [ ClaudeAgent::ToolUseBlock.new(id: "t1", name: "Read", input: {}) ],
      model: "claude"
    )
    @turn << make_result

    result = @turn.inspect
    assert_match(/tools=1/, result)
  end

  # --- Realistic Multi-Tool Turn ---

  test "realistic multi-tool turn" do
    # Claude reads a file, then edits it
    @turn << ClaudeAgent::AssistantMessage.new(
      content: [
        ClaudeAgent::TextBlock.new(text: "Let me read the file first."),
        ClaudeAgent::ToolUseBlock.new(id: "t1", name: "Read", input: { file_path: "/app/lib/foo.rb" })
      ],
      model: "claude-sonnet-4-5-20250514"
    )

    @turn << ClaudeAgent::UserMessage.new(
      content: [ ClaudeAgent::ToolResultBlock.new(tool_use_id: "t1", content: "def foo\n  :bar\nend") ]
    )

    @turn << ClaudeAgent::AssistantMessage.new(
      content: [
        ClaudeAgent::TextBlock.new(text: "Now I'll fix the method."),
        ClaudeAgent::ToolUseBlock.new(
          id: "t2", name: "Edit",
          input: { file_path: "/app/lib/foo.rb", old_string: ":bar", new_string: ":baz" }
        )
      ],
      model: "claude-sonnet-4-5-20250514"
    )

    @turn << ClaudeAgent::UserMessage.new(
      content: [ ClaudeAgent::ToolResultBlock.new(tool_use_id: "t2", content: "OK") ]
    )

    @turn << ClaudeAgent::AssistantMessage.new(
      content: [ ClaudeAgent::TextBlock.new(text: "Done! I fixed the method.") ],
      model: "claude-sonnet-4-5-20250514"
    )

    @turn << make_result(
      usage: { input_tokens: 500, output_tokens: 200 },
      total_cost_usd: 0.05,
      duration_ms: 3000,
      duration_api_ms: 2500,
      session_id: "session-xyz",
      num_turns: 1
    )

    assert @turn.complete?
    assert @turn.success?

    assert_equal "Let me read the file first.Now I'll fix the method.Done! I fixed the method.", @turn.text
    assert_equal "claude-sonnet-4-5-20250514", @turn.model

    assert_equal 2, @turn.tool_uses.size
    assert_equal "Read", @turn.tool_uses[0].name
    assert_equal "Edit", @turn.tool_uses[1].name

    assert_equal 2, @turn.tool_results.size

    execs = @turn.tool_executions
    assert_equal 2, execs.size
    assert_equal "Read", execs[0][:tool_use].name
    assert_equal "def foo\n  :bar\nend", execs[0][:tool_result].content
    assert_equal "Edit", execs[1][:tool_use].name
    assert_equal "OK", execs[1][:tool_result].content

    assert_equal 500, @turn.usage[:input_tokens]
    assert_equal 0.05, @turn.cost
    assert_equal 3000, @turn.duration_ms
    assert_equal "session-xyz", @turn.session_id
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
    usage: nil,
    total_cost_usd: nil,
    duration_ms: 0,
    duration_api_ms: 0,
    session_id: "session-test",
    num_turns: 1,
    stop_reason: nil,
    errors: nil,
    permission_denials: nil,
    model_usage: nil,
    structured_output: nil
  )
    ClaudeAgent::ResultMessage.new(
      subtype: subtype,
      duration_ms: duration_ms,
      duration_api_ms: duration_api_ms,
      is_error: is_error,
      num_turns: num_turns,
      session_id: session_id,
      total_cost_usd: total_cost_usd,
      usage: usage,
      errors: errors,
      permission_denials: permission_denials,
      model_usage: model_usage,
      structured_output: structured_output,
      stop_reason: stop_reason
    )
  end

  def make_user_with_tool_result(tool_use_id, content, is_error: nil)
    ClaudeAgent::UserMessage.new(
      content: [ ClaudeAgent::ToolResultBlock.new(tool_use_id: tool_use_id, content: content, is_error: is_error) ]
    )
  end
end
