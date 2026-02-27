# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentToolActivityTracker < ActiveSupport::TestCase
  setup do
    @handler = ClaudeAgent::EventHandler.new
    @tracker = ClaudeAgent::ToolActivityTracker.attach(@handler)
  end

  def make_tool_use(id: "tool-1", name: "Read", input: { file_path: "/tmp/test.rb" })
    ClaudeAgent::ToolUseBlock.new(id: id, name: name, input: input)
  end

  def make_tool_result(tool_use_id: "tool-1", content: "data", is_error: false)
    ClaudeAgent::ToolResultBlock.new(
      tool_use_id: tool_use_id,
      content: content,
      is_error: is_error
    )
  end

  def make_tool_progress(tool_use_id: "tool-1", elapsed: 2.5)
    ClaudeAgent::ToolProgressMessage.new(
      uuid: "msg-1",
      session_id: "session-1",
      tool_use_id: tool_use_id,
      tool_name: "Read",
      elapsed_time_seconds: elapsed
    )
  end

  def emit_tool_use(tool_use)
    msg = ClaudeAgent::AssistantMessage.new(
      content: [ tool_use ],
      model: "claude"
    )
    @handler.handle(msg)
  end

  def emit_tool_result(tool_result)
    msg = ClaudeAgent::UserMessage.new(
      content: [ tool_result ]
    )
    @handler.handle(msg)
  end

  def emit_tool_progress(progress)
    @handler.handle(progress)
  end

  # --- Initialization ---

  test "initializes empty" do
    assert @tracker.empty?
    assert_equal 0, @tracker.size
  end

  # --- Tracking tool_use ---

  test "tracks tool_use as running" do
    tool_use = make_tool_use
    emit_tool_use(tool_use)

    assert_equal 1, @tracker.size
    entry = @tracker.first
    assert_instance_of ClaudeAgent::LiveToolActivity, entry
    assert entry.running?
    assert_equal "tool-1", entry.id
  end

  # --- Tracking tool_result ---

  test "tracks tool_result as done" do
    emit_tool_use(make_tool_use)
    emit_tool_result(make_tool_result)

    entry = @tracker.first
    assert entry.done?
    refute entry.running?
  end

  test "tracks tool_result as error" do
    emit_tool_use(make_tool_use)
    emit_tool_result(make_tool_result(is_error: true))

    entry = @tracker.first
    assert entry.error?
  end

  test "ignores tool_result for unknown ID" do
    # Should not raise
    emit_tool_result(make_tool_result(tool_use_id: "unknown"))
    assert @tracker.empty?
  end

  # --- Tracking tool_progress ---

  test "tracks tool_progress elapsed" do
    emit_tool_use(make_tool_use)
    emit_tool_progress(make_tool_progress(elapsed: 3.7))

    entry = @tracker.first
    assert_equal 3.7, entry.elapsed
  end

  test "ignores tool_progress for unknown ID" do
    # Should not raise
    emit_tool_progress(make_tool_progress(tool_use_id: "unknown"))
    assert @tracker.empty?
  end

  # --- Enumerable ---

  test "each iterates entries" do
    emit_tool_use(make_tool_use(id: "t1"))
    emit_tool_use(make_tool_use(id: "t2"))

    ids = @tracker.map(&:id)
    assert_equal %w[t1 t2], ids
  end

  test "select works" do
    emit_tool_use(make_tool_use(id: "t1"))
    emit_tool_use(make_tool_use(id: "t2"))
    emit_tool_result(make_tool_result(tool_use_id: "t1"))

    running = @tracker.select(&:running?)
    assert_equal 1, running.size
    assert_equal "t2", running.first.id
  end

  # --- Lookup ---

  test "find_by_id returns entry" do
    emit_tool_use(make_tool_use(id: "t1"))
    entry = @tracker.find_by_id("t1")
    assert_equal "t1", entry.id
  end

  test "find_by_id returns nil for unknown" do
    assert_nil @tracker.find_by_id("unknown")
  end

  test "bracket alias works" do
    emit_tool_use(make_tool_use(id: "t1"))
    assert_equal "t1", @tracker["t1"].id
  end

  # --- Filtered views ---

  test "running returns only running entries" do
    emit_tool_use(make_tool_use(id: "t1"))
    emit_tool_use(make_tool_use(id: "t2"))
    emit_tool_result(make_tool_result(tool_use_id: "t1"))

    assert_equal %w[t2], @tracker.running.map(&:id)
  end

  test "done returns only done entries" do
    emit_tool_use(make_tool_use(id: "t1"))
    emit_tool_use(make_tool_use(id: "t2"))
    emit_tool_result(make_tool_result(tool_use_id: "t1"))

    assert_equal %w[t1], @tracker.done.map(&:id)
  end

  test "errored returns only error entries" do
    emit_tool_use(make_tool_use(id: "t1"))
    emit_tool_use(make_tool_use(id: "t2"))
    emit_tool_result(make_tool_result(tool_use_id: "t1", is_error: true))

    assert_equal %w[t1], @tracker.errored.map(&:id)
  end

  # --- reset! ---

  test "reset clears all state" do
    emit_tool_use(make_tool_use(id: "t1"))
    emit_tool_use(make_tool_use(id: "t2"))

    @tracker.reset!

    assert @tracker.empty?
    assert_nil @tracker.find_by_id("t1")
    assert_nil @tracker.find_by_id("t2")
  end

  # --- Specific callbacks ---

  test "on_start fires for tool use" do
    entries = []
    @tracker.on_start { |entry| entries << entry.id }

    emit_tool_use(make_tool_use)

    assert_equal [ "tool-1" ], entries
  end

  test "on_complete fires for tool result" do
    entries = []
    @tracker.on_complete { |entry| entries << entry.id }

    emit_tool_use(make_tool_use)
    emit_tool_result(make_tool_result)

    assert_equal [ "tool-1" ], entries
  end

  test "on_progress fires for tool progress" do
    entries = []
    @tracker.on_progress { |entry| entries << entry.elapsed }

    emit_tool_use(make_tool_use)
    emit_tool_progress(make_tool_progress(elapsed: 3.7))

    assert_equal [ 3.7 ], entries
  end

  test "specific and catch-all callbacks both fire" do
    specific = []
    catchall = []
    @tracker.on_start { |entry| specific << entry.id }
    @tracker.on_change { |event, entry| catchall << [ event, entry.id ] }

    emit_tool_use(make_tool_use)

    assert_equal [ "tool-1" ], specific
    assert_equal [ [ :started, "tool-1" ] ], catchall
  end

  # --- on_change (catch-all) ---

  test "on_change fires started" do
    events = []
    @tracker.on_change { |event, entry| events << [ event, entry.id ] }

    emit_tool_use(make_tool_use)

    assert_equal [ [ :started, "tool-1" ] ], events
  end

  test "on_change fires completed" do
    events = []
    @tracker.on_change { |event, entry| events << [ event, entry.id ] }

    emit_tool_use(make_tool_use)
    emit_tool_result(make_tool_result)

    assert_equal [ [ :started, "tool-1" ], [ :completed, "tool-1" ] ], events
  end

  test "on_change fires progress" do
    events = []
    @tracker.on_change { |event, entry| events << [ event, entry.id ] }

    emit_tool_use(make_tool_use)
    emit_tool_progress(make_tool_progress)

    assert_equal [ [ :started, "tool-1" ], [ :progress, "tool-1" ] ], events
  end

  test "callbacks are optional" do
    # No callbacks registered — should not error
    assert_nothing_raised do
      emit_tool_use(make_tool_use)
      emit_tool_result(make_tool_result)
    end
  end

  # --- attach with Client ---

  test "attach works with Client" do
    transport = MockTransport.new
    client = ClaudeAgent::Client.new(transport: transport)

    tracker = ClaudeAgent::ToolActivityTracker.attach(client)
    assert_instance_of ClaudeAgent::ToolActivityTracker, tracker
  end

  test "attach works with EventHandler" do
    handler = ClaudeAgent::EventHandler.new
    tracker = ClaudeAgent::ToolActivityTracker.attach(handler)
    assert_instance_of ClaudeAgent::ToolActivityTracker, tracker
  end

  # --- Realistic multi-tool turn ---

  test "multi-tool turn lifecycle" do
    events = []
    @tracker.on_change { |event, entry| events << [ event, entry.id, entry.status ] }

    # Two tools start
    emit_tool_use(make_tool_use(id: "t1", name: "Read"))
    emit_tool_use(make_tool_use(id: "t2", name: "Bash", input: { command: "ls" }))

    assert_equal 2, @tracker.running.size

    # Progress on t2
    emit_tool_progress(make_tool_progress(tool_use_id: "t2", elapsed: 1.5))
    assert_equal 1.5, @tracker["t2"].elapsed

    # t1 completes
    emit_tool_result(make_tool_result(tool_use_id: "t1"))
    assert_equal 1, @tracker.running.size
    assert_equal 1, @tracker.done.size

    # t2 errors
    emit_tool_result(make_tool_result(tool_use_id: "t2", is_error: true))
    assert_equal 0, @tracker.running.size
    assert_equal 1, @tracker.done.size
    assert_equal 1, @tracker.errored.size

    expected_events = [
      [ :started, "t1", :running ],
      [ :started, "t2", :running ],
      [ :progress, "t2", :running ],
      [ :completed, "t1", :done ],
      [ :completed, "t2", :error ]
    ]
    assert_equal expected_events, events
  end
end
