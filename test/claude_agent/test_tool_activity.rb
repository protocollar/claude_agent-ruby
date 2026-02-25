# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentToolActivity < ActiveSupport::TestCase
  setup do
    @tool_use = ClaudeAgent::ToolUseBlock.new(
      id: "tool-1",
      name: "Read",
      input: { file_path: "/tmp/test.rb" }
    )
    @tool_result = ClaudeAgent::ToolResultBlock.new(
      tool_use_id: "tool-1",
      content: "file contents",
      is_error: false
    )
  end

  test "attributes" do
    activity = ClaudeAgent::ToolActivity.new(
      tool_use: @tool_use,
      tool_result: @tool_result,
      turn_index: 0,
      started_at: Time.new(2026, 1, 1, 0, 0, 0),
      completed_at: Time.new(2026, 1, 1, 0, 0, 2)
    )

    assert_equal @tool_use, activity.tool_use
    assert_equal @tool_result, activity.tool_result
    assert_equal 0, activity.turn_index
  end

  test "delegates name" do
    activity = ClaudeAgent::ToolActivity.new(tool_use: @tool_use, turn_index: 0)
    assert_equal "Read", activity.name
  end

  test "delegates display_label" do
    activity = ClaudeAgent::ToolActivity.new(tool_use: @tool_use, turn_index: 0)
    assert_equal "Read tmp/test.rb", activity.display_label
  end

  test "delegates summary" do
    activity = ClaudeAgent::ToolActivity.new(tool_use: @tool_use, turn_index: 0)
    assert_equal "Read: /tmp/test.rb", activity.summary
  end

  test "delegates file_path" do
    activity = ClaudeAgent::ToolActivity.new(tool_use: @tool_use, turn_index: 0)
    assert_equal "/tmp/test.rb", activity.file_path
  end

  test "delegates id" do
    activity = ClaudeAgent::ToolActivity.new(tool_use: @tool_use, turn_index: 0)
    assert_equal "tool-1", activity.id
  end

  test "complete when tool_result present" do
    activity = ClaudeAgent::ToolActivity.new(
      tool_use: @tool_use,
      tool_result: @tool_result,
      turn_index: 0
    )
    assert activity.complete?
  end

  test "not complete when tool_result nil" do
    activity = ClaudeAgent::ToolActivity.new(tool_use: @tool_use, turn_index: 0)
    refute activity.complete?
  end

  test "error when tool_result is_error" do
    error_result = ClaudeAgent::ToolResultBlock.new(
      tool_use_id: "tool-1",
      content: "Permission denied",
      is_error: true
    )
    activity = ClaudeAgent::ToolActivity.new(
      tool_use: @tool_use,
      tool_result: error_result,
      turn_index: 0
    )
    assert activity.error?
  end

  test "not error when tool_result succeeds" do
    activity = ClaudeAgent::ToolActivity.new(
      tool_use: @tool_use,
      tool_result: @tool_result,
      turn_index: 0
    )
    refute activity.error?
  end

  test "not error when no result" do
    activity = ClaudeAgent::ToolActivity.new(tool_use: @tool_use, turn_index: 0)
    refute activity.error?
  end

  test "duration with timestamps" do
    activity = ClaudeAgent::ToolActivity.new(
      tool_use: @tool_use,
      turn_index: 0,
      started_at: Time.new(2026, 1, 1, 0, 0, 0),
      completed_at: Time.new(2026, 1, 1, 0, 0, 3)
    )
    assert_equal 3.0, activity.duration
  end

  test "duration nil without timestamps" do
    activity = ClaudeAgent::ToolActivity.new(tool_use: @tool_use, turn_index: 0)
    assert_nil activity.duration
  end

  test "duration nil with only started_at" do
    activity = ClaudeAgent::ToolActivity.new(
      tool_use: @tool_use,
      turn_index: 0,
      started_at: Time.now
    )
    assert_nil activity.duration
  end

  test "defaults" do
    activity = ClaudeAgent::ToolActivity.new(tool_use: @tool_use, turn_index: 0)

    assert_nil activity.tool_result
    assert_nil activity.started_at
    assert_nil activity.completed_at
  end

  test "frozen" do
    activity = ClaudeAgent::ToolActivity.new(tool_use: @tool_use, turn_index: 0)
    assert activity.frozen?
  end
end
