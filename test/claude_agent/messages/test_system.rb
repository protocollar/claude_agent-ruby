# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentMessagesSystem < ActiveSupport::TestCase
  test "system_message" do
    msg = ClaudeAgent::SystemMessage.new(
      subtype: "init",
      data: { version: "2.0.0" }
    )
    assert_equal "init", msg.subtype
    assert_equal({ version: "2.0.0" }, msg.data)
    assert_equal :system, msg.type
  end

  test "compact_boundary_message" do
    msg = ClaudeAgent::CompactBoundaryMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      compact_metadata: { trigger: "auto", pre_tokens: 50000 }
    )

    assert_equal "msg-123", msg.uuid
    assert_equal "session-abc", msg.session_id
    assert_equal :compact_boundary, msg.type
    assert_equal "auto", msg.trigger
    assert_equal 50000, msg.pre_tokens
  end

  test "compact_boundary_message_with_symbol_keys" do
    msg = ClaudeAgent::CompactBoundaryMessage.new(
      uuid: "msg-456",
      session_id: "session-xyz",
      compact_metadata: { trigger: "manual", pre_tokens: 25000 }
    )

    assert_equal "manual", msg.trigger
    assert_equal 25000, msg.pre_tokens
  end

  test "compact_boundary_message_in_types_constant" do
    assert_includes ClaudeAgent::MESSAGE_TYPES, ClaudeAgent::CompactBoundaryMessage
  end

  test "status_message" do
    msg = ClaudeAgent::StatusMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      status: "compacting"
    )
    assert_equal "msg-123", msg.uuid
    assert_equal "session-abc", msg.session_id
    assert_equal "compacting", msg.status
    assert_equal :status, msg.type
  end

  test "status_message_with_permission_mode" do
    msg = ClaudeAgent::StatusMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      status: "compacting",
      permission_mode: "acceptEdits"
    )
    assert_equal "acceptEdits", msg.permission_mode
  end

  test "status_message_permission_mode_default_nil" do
    msg = ClaudeAgent::StatusMessage.new(
      uuid: "msg-123",
      session_id: "session-abc",
      status: "compacting"
    )
    assert_nil msg.permission_mode
  end

  test "status_message_in_types_constant" do
    assert_includes ClaudeAgent::MESSAGE_TYPES, ClaudeAgent::StatusMessage
  end
end
