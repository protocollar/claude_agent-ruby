# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentTypesOperations < ActiveSupport::TestCase
  # --- TaskUsage ---

  test "task_usage" do
    usage = ClaudeAgent::TaskUsage.new(
      total_tokens: 5000,
      tool_uses: 3,
      duration_ms: 2500
    )
    assert_equal 5000, usage.total_tokens
    assert_equal 3, usage.tool_uses
    assert_equal 2500, usage.duration_ms
  end

  test "task_usage_defaults" do
    usage = ClaudeAgent::TaskUsage.new
    assert_equal 0, usage.total_tokens
    assert_equal 0, usage.tool_uses
    assert_equal 0, usage.duration_ms
  end

  # --- SDKPermissionDenial ---

  test "sdk_permission_denial" do
    denial = ClaudeAgent::SDKPermissionDenial.new(
      tool_name: "Write",
      tool_use_id: "tool-123",
      tool_input: { file_path: "/etc/passwd" }
    )
    assert_equal "Write", denial.tool_name
    assert_equal "tool-123", denial.tool_use_id
    assert_equal({ file_path: "/etc/passwd" }, denial.tool_input)
  end

  # --- RewindFilesResult ---

  test "rewind_files_result" do
    result = ClaudeAgent::RewindFilesResult.new(
      can_rewind: true,
      files_changed: [ "src/foo.rb", "src/bar.rb" ],
      insertions: 10,
      deletions: 5
    )
    assert result.can_rewind
    assert_nil result.error
    assert_equal [ "src/foo.rb", "src/bar.rb" ], result.files_changed
    assert_equal 10, result.insertions
    assert_equal 5, result.deletions
  end

  test "rewind_files_result_with_error" do
    result = ClaudeAgent::RewindFilesResult.new(
      can_rewind: false,
      error: "No checkpoint found"
    )
    refute result.can_rewind
    assert_equal "No checkpoint found", result.error
    assert_nil result.files_changed
    assert_nil result.insertions
    assert_nil result.deletions
  end
end
