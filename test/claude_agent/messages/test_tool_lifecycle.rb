# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentMessagesToolLifecycle < ActiveSupport::TestCase
  test "tool_progress_message" do
    msg = ClaudeAgent::ToolProgressMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      tool_use_id: "tool-456",
      tool_name: "Bash",
      elapsed_time_seconds: 5.2
    )
    assert_equal "msg-123", msg.uuid
    assert_equal "session-abc", msg.session_id
    assert_equal "tool-456", msg.tool_use_id
    assert_equal "Bash", msg.tool_name
    assert_equal 5.2, msg.elapsed_time_seconds
    assert_nil msg.parent_tool_use_id
    assert_equal :tool_progress, msg.type
  end

  test "tool_progress_message_with_parent" do
    msg = ClaudeAgent::ToolProgressMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      tool_use_id: "tool-456",
      tool_name: "Bash",
      elapsed_time_seconds: 5.2,
      parent_tool_use_id: "parent-789"
    )
    assert_equal "parent-789", msg.parent_tool_use_id
  end

  test "tool_progress_message_with_task_id" do
    msg = ClaudeAgent::ToolProgressMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      tool_use_id: "tool-456",
      tool_name: "Bash",
      elapsed_time_seconds: 5.2,
      task_id: "task-789"
    )
    assert_equal "task-789", msg.task_id
  end

  test "tool_progress_message_task_id_default_nil" do
    msg = ClaudeAgent::ToolProgressMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      tool_use_id: "tool-456",
      tool_name: "Bash",
      elapsed_time_seconds: 5.2
    )
    assert_nil msg.task_id
  end

  test "tool_progress_message_in_types_constant" do
    assert_includes ClaudeAgent::MESSAGE_TYPES, ClaudeAgent::ToolProgressMessage
  end

  test "tool_use_summary_message" do
    msg = ClaudeAgent::ToolUseSummaryMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      summary: "Read 3 files",
      preceding_tool_use_ids: [ "tool-1", "tool-2", "tool-3" ]
    )
    assert_equal "msg-123", msg.uuid
    assert_equal "session-abc", msg.session_id
    assert_equal "Read 3 files", msg.summary
    assert_equal [ "tool-1", "tool-2", "tool-3" ], msg.preceding_tool_use_ids
    assert_equal :tool_use_summary, msg.type
  end

  test "tool_use_summary_message_defaults" do
    msg = ClaudeAgent::ToolUseSummaryMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      summary: "Read files"
    )
    assert_equal [], msg.preceding_tool_use_ids
  end

  test "tool_use_summary_message_in_types_constant" do
    assert_includes ClaudeAgent::MESSAGE_TYPES, ClaudeAgent::ToolUseSummaryMessage
  end

  test "local_command_output_message" do
    msg = ClaudeAgent::LocalCommandOutputMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      content: "command output here"
    )
    assert_equal "msg-123", msg.uuid
    assert_equal "session-abc", msg.session_id
    assert_equal "command output here", msg.content
    assert_equal :local_command_output, msg.type
  end

  test "local_command_output_message_defaults" do
    msg = ClaudeAgent::LocalCommandOutputMessage.new
    assert_equal "", msg.uuid
    assert_equal "", msg.session_id
    assert_equal "", msg.content
  end

  test "local_command_output_message_in_types_constant" do
    assert_includes ClaudeAgent::MESSAGE_TYPES, ClaudeAgent::LocalCommandOutputMessage
  end
end
