# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentLiveToolActivity < ActiveSupport::TestCase
  setup do
    @tool_use = ClaudeAgent::ToolUseBlock.new(
      id: "tool-1",
      name: "Read",
      input: { file_path: "/tmp/test.rb" }
    )
  end

  # --- Initialization ---

  test "initializes with running status" do
    activity = ClaudeAgent::LiveToolActivity.new(@tool_use)
    assert_equal :running, activity.status
    assert activity.running?
  end

  test "initializes with started_at timestamp" do
    before = Time.now
    activity = ClaudeAgent::LiveToolActivity.new(@tool_use)
    after = Time.now

    assert_instance_of Time, activity.started_at
    assert activity.started_at >= before
    assert activity.started_at <= after
  end

  test "initializes with nil elapsed" do
    activity = ClaudeAgent::LiveToolActivity.new(@tool_use)
    assert_nil activity.elapsed
  end

  test "initializes with nil tool_result" do
    activity = ClaudeAgent::LiveToolActivity.new(@tool_use)
    assert_nil activity.tool_result
  end

  # --- Delegation ---

  test "delegates id to tool_use" do
    activity = ClaudeAgent::LiveToolActivity.new(@tool_use)
    assert_equal "tool-1", activity.id
  end

  test "delegates name to tool_use" do
    activity = ClaudeAgent::LiveToolActivity.new(@tool_use)
    assert_equal "Read", activity.name
  end

  test "delegates input to tool_use" do
    activity = ClaudeAgent::LiveToolActivity.new(@tool_use)
    assert_equal({ file_path: "/tmp/test.rb" }, activity.input)
  end

  test "delegates display_label to tool_use" do
    activity = ClaudeAgent::LiveToolActivity.new(@tool_use)
    assert_equal "Read tmp/test.rb", activity.display_label
  end

  test "delegates summary to tool_use" do
    activity = ClaudeAgent::LiveToolActivity.new(@tool_use)
    assert_equal "Read: /tmp/test.rb", activity.summary
  end

  test "delegates file_path to tool_use" do
    activity = ClaudeAgent::LiveToolActivity.new(@tool_use)
    assert_equal "/tmp/test.rb", activity.file_path
  end

  # --- complete! ---

  test "complete transitions to done on success" do
    activity = ClaudeAgent::LiveToolActivity.new(@tool_use)
    result = ClaudeAgent::ToolResultBlock.new(
      tool_use_id: "tool-1",
      content: "file contents",
      is_error: false
    )

    activity.complete!(result)

    assert_equal :done, activity.status
    assert activity.done?
    refute activity.running?
    refute activity.error?
  end

  test "complete transitions to error on is_error" do
    activity = ClaudeAgent::LiveToolActivity.new(@tool_use)
    result = ClaudeAgent::ToolResultBlock.new(
      tool_use_id: "tool-1",
      content: "Permission denied",
      is_error: true
    )

    activity.complete!(result)

    assert_equal :error, activity.status
    assert activity.error?
    refute activity.running?
    refute activity.done?
  end

  test "complete sets tool_result" do
    activity = ClaudeAgent::LiveToolActivity.new(@tool_use)
    result = ClaudeAgent::ToolResultBlock.new(
      tool_use_id: "tool-1",
      content: "data"
    )

    activity.complete!(result)
    assert_equal result, activity.tool_result
  end

  test "complete calculates elapsed from started_at" do
    activity = ClaudeAgent::LiveToolActivity.new(@tool_use)
    result = ClaudeAgent::ToolResultBlock.new(tool_use_id: "tool-1")

    activity.complete!(result)

    assert_instance_of Float, activity.elapsed
    assert activity.elapsed >= 0
  end

  test "complete preserves elapsed if already set by update_elapsed" do
    activity = ClaudeAgent::LiveToolActivity.new(@tool_use)
    activity.update_elapsed(5.2)

    result = ClaudeAgent::ToolResultBlock.new(tool_use_id: "tool-1")
    activity.complete!(result)

    assert_equal 5.2, activity.elapsed
  end

  # --- update_elapsed ---

  test "update_elapsed sets elapsed from progress" do
    activity = ClaudeAgent::LiveToolActivity.new(@tool_use)
    activity.update_elapsed(3.7)
    assert_equal 3.7, activity.elapsed
  end

  # --- Predicates ---

  test "complete? is true for done" do
    activity = ClaudeAgent::LiveToolActivity.new(@tool_use)
    result = ClaudeAgent::ToolResultBlock.new(tool_use_id: "tool-1", is_error: false)
    activity.complete!(result)
    assert activity.complete?
  end

  test "complete? is true for error" do
    activity = ClaudeAgent::LiveToolActivity.new(@tool_use)
    result = ClaudeAgent::ToolResultBlock.new(tool_use_id: "tool-1", is_error: true)
    activity.complete!(result)
    assert activity.complete?
  end

  test "complete? is false while running" do
    activity = ClaudeAgent::LiveToolActivity.new(@tool_use)
    refute activity.complete?
  end

  # --- to_h ---

  test "to_h returns hash representation" do
    activity = ClaudeAgent::LiveToolActivity.new(@tool_use)
    h = activity.to_h

    assert_equal "tool-1", h[:id]
    assert_equal "Read", h[:name]
    assert_equal :running, h[:status]
    assert_nil h[:elapsed]
    assert_instance_of Time, h[:started_at]
  end

  # --- inspect ---

  test "inspect includes key info" do
    activity = ClaudeAgent::LiveToolActivity.new(@tool_use)
    output = activity.inspect

    assert_includes output, "LiveToolActivity"
    assert_includes output, "id=tool-1"
    assert_includes output, "name=Read"
    assert_includes output, "status=running"
  end

  test "inspect includes elapsed when present" do
    activity = ClaudeAgent::LiveToolActivity.new(@tool_use)
    activity.update_elapsed(2.5)

    assert_includes activity.inspect, "elapsed=2.5s"
  end
end
