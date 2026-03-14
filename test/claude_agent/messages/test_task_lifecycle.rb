# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentMessagesTaskLifecycle < ActiveSupport::TestCase
  test "task_started_message" do
    msg = ClaudeAgent::TaskStartedMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      task_id: "task-456",
      tool_use_id: "tool-789",
      description: "Running tests",
      task_type: "bash",
      prompt: "Run the test suite"
    )
    assert_equal "msg-123", msg.uuid
    assert_equal "session-abc", msg.session_id
    assert_equal "task-456", msg.task_id
    assert_equal "tool-789", msg.tool_use_id
    assert_equal "Running tests", msg.description
    assert_equal "bash", msg.task_type
    assert_equal "Run the test suite", msg.prompt
    assert_equal :task_started, msg.type
  end

  test "task_started_message_defaults" do
    msg = ClaudeAgent::TaskStartedMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      task_id: "task-456"
    )
    assert_nil msg.tool_use_id
    assert_nil msg.description
    assert_nil msg.task_type
    assert_nil msg.prompt
  end

  test "task_started_message_in_types_constant" do
    assert_includes ClaudeAgent::MESSAGE_TYPES, ClaudeAgent::TaskStartedMessage
  end

  test "task_progress_message" do
    usage = { total_tokens: 5000, tool_uses: 3, duration_ms: 2500 }
    msg = ClaudeAgent::TaskProgressMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      task_id: "task-456",
      tool_use_id: "tool-789",
      description: "Searching codebase",
      usage: usage,
      last_tool_name: "Grep",
      summary: "Analyzing authentication module"
    )
    assert_equal "msg-123", msg.uuid
    assert_equal "session-abc", msg.session_id
    assert_equal "task-456", msg.task_id
    assert_equal "tool-789", msg.tool_use_id
    assert_equal "Searching codebase", msg.description
    assert_equal usage, msg.usage
    assert_equal "Grep", msg.last_tool_name
    assert_equal "Analyzing authentication module", msg.summary
    assert_equal :task_progress, msg.type
  end

  test "task_progress_message_defaults" do
    msg = ClaudeAgent::TaskProgressMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      task_id: "task-456",
      description: "Running tests"
    )
    assert_nil msg.tool_use_id
    assert_nil msg.usage
    assert_nil msg.last_tool_name
    assert_nil msg.summary
  end

  test "task_progress_message_in_types_constant" do
    assert_includes ClaudeAgent::MESSAGE_TYPES, ClaudeAgent::TaskProgressMessage
  end

  test "task_notification_message" do
    msg = ClaudeAgent::TaskNotificationMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      task_id: "task-456",
      status: "completed",
      output_file: "/path/to/output.txt",
      summary: "Task completed successfully"
    )
    assert_equal "msg-123", msg.uuid
    assert_equal "session-abc", msg.session_id
    assert_equal "task-456", msg.task_id
    assert_equal "completed", msg.status
    assert_equal "/path/to/output.txt", msg.output_file
    assert_equal "Task completed successfully", msg.summary
    assert_equal :task_notification, msg.type
  end

  test "task_notification_completed?" do
    msg = ClaudeAgent::TaskNotificationMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      task_id: "task-456",
      status: "completed",
      output_file: "/path/to/output.txt",
      summary: "Done"
    )
    assert msg.completed?
    refute msg.failed?
    refute msg.stopped?
  end

  test "task_notification_failed?" do
    msg = ClaudeAgent::TaskNotificationMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      task_id: "task-456",
      status: "failed",
      output_file: "/path/to/output.txt",
      summary: "Error occurred"
    )
    refute msg.completed?
    assert msg.failed?
    refute msg.stopped?
  end

  test "task_notification_stopped?" do
    msg = ClaudeAgent::TaskNotificationMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      task_id: "task-456",
      status: "stopped",
      output_file: "/path/to/output.txt",
      summary: "Manually stopped"
    )
    refute msg.completed?
    refute msg.failed?
    assert msg.stopped?
  end

  test "task_notification_message_with_tool_use_id_and_usage" do
    usage = ClaudeAgent::TaskUsage.new(total_tokens: 5000, tool_uses: 3, duration_ms: 2500)
    msg = ClaudeAgent::TaskNotificationMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      task_id: "task-456",
      status: "completed",
      output_file: "/path/to/output.txt",
      summary: "Done",
      tool_use_id: "tool-789",
      usage: usage
    )
    assert_equal "tool-789", msg.tool_use_id
    assert_equal 5000, msg.usage.total_tokens
    assert_equal 3, msg.usage.tool_uses
    assert_equal 2500, msg.usage.duration_ms
  end

  test "task_notification_message_new_fields_default_nil" do
    msg = ClaudeAgent::TaskNotificationMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      task_id: "task-456",
      status: "completed",
      output_file: "/path/to/output.txt",
      summary: "Done"
    )
    assert_nil msg.tool_use_id
    assert_nil msg.usage
  end

  test "task_notification_message_in_types_constant" do
    assert_includes ClaudeAgent::MESSAGE_TYPES, ClaudeAgent::TaskNotificationMessage
  end

  test "files_persisted_event" do
    files = [ { "filename" => "test.rb", "file_id" => "file-456" } ]
    failed = [ { "filename" => "bad.rb", "error" => "Permission denied" } ]
    msg = ClaudeAgent::FilesPersistedEvent.new(
      uuid: "msg-123",
      session_id: "session-abc",
      files: files,
      failed: failed,
      processed_at: "2026-01-30T12:00:00Z"
    )
    assert_equal "msg-123", msg.uuid
    assert_equal "session-abc", msg.session_id
    assert_equal files, msg.files
    assert_equal failed, msg.failed
    assert_equal "2026-01-30T12:00:00Z", msg.processed_at
    assert_equal :files_persisted, msg.type
  end

  test "files_persisted_event_defaults" do
    msg = ClaudeAgent::FilesPersistedEvent.new(
      uuid: "msg-123",
      session_id: "session-abc"
    )
    assert_equal [], msg.files
    assert_equal [], msg.failed
    assert_nil msg.processed_at
  end

  test "files_persisted_event_in_types_constant" do
    assert_includes ClaudeAgent::MESSAGE_TYPES, ClaudeAgent::FilesPersistedEvent
  end

  test "elicitation_complete_message" do
    msg = ClaudeAgent::ElicitationCompleteMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      mcp_server_name: "my-server",
      elicitation_id: "elic-456"
    )
    assert_equal "msg-123", msg.uuid
    assert_equal "session-abc", msg.session_id
    assert_equal "my-server", msg.mcp_server_name
    assert_equal "elic-456", msg.elicitation_id
    assert_equal :elicitation_complete, msg.type
  end

  test "elicitation_complete_message_defaults" do
    msg = ClaudeAgent::ElicitationCompleteMessage.new
    assert_equal "", msg.uuid
    assert_equal "", msg.session_id
    assert_equal "", msg.mcp_server_name
    assert_equal "", msg.elicitation_id
  end

  test "elicitation_complete_message_in_types_constant" do
    assert_includes ClaudeAgent::MESSAGE_TYPES, ClaudeAgent::ElicitationCompleteMessage
  end

  test "auth_status_message" do
    msg = ClaudeAgent::AuthStatusMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      is_authenticating: true,
      output: [ "Waiting for browser..." ],
      error: nil
    )
    assert_equal "msg-123", msg.uuid
    assert_equal "session-abc", msg.session_id
    assert_equal true, msg.is_authenticating
    assert_equal [ "Waiting for browser..." ], msg.output
    assert_nil msg.error
    assert_equal :auth_status, msg.type
  end

  test "auth_status_message_with_error" do
    msg = ClaudeAgent::AuthStatusMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      is_authenticating: false,
      error: "Authentication failed"
    )
    assert_equal "Authentication failed", msg.error
    refute msg.is_authenticating
    assert_equal [], msg.output
  end

  test "auth_status_message_in_types_constant" do
    assert_includes ClaudeAgent::MESSAGE_TYPES, ClaudeAgent::AuthStatusMessage
  end
end
