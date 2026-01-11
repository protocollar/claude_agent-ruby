# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentErrors < ActiveSupport::TestCase
  test "base_error" do
    error = ClaudeAgent::Error.new("test message")
    assert_equal "test message", error.message
  end

  test "cli_not_found_error_default_message" do
    error = ClaudeAgent::CLINotFoundError.new
    assert_match(/Claude Code CLI not found/, error.message)
  end

  test "cli_version_error_with_version" do
    error = ClaudeAgent::CLIVersionError.new("1.0.0")
    assert_match(/1\.0\.0/, error.message)
    assert_match(/2\.0\.0/, error.message)
  end

  test "cli_version_error_without_version" do
    error = ClaudeAgent::CLIVersionError.new
    assert_match(/Could not determine/, error.message)
  end

  test "process_error_with_exit_code" do
    error = ClaudeAgent::ProcessError.new("Failed", exit_code: 1, stderr: "error output")
    assert_equal 1, error.exit_code
    assert_equal "error output", error.stderr
    assert_match(/exit code: 1/, error.message)
    assert_match(/error output/, error.message)
  end

  test "json_decode_error_with_content" do
    error = ClaudeAgent::JSONDecodeError.new("Parse failed", raw_content: '{"broken":')
    assert_equal '{"broken":', error.raw_content
    assert_match(/Parse failed/, error.message)
  end

  test "message_parse_error" do
    error = ClaudeAgent::MessageParseError.new("Unknown type", raw_message: { type: "unknown" })
    assert_equal({ type: "unknown" }, error.raw_message)
  end

  test "timeout_error" do
    error = ClaudeAgent::TimeoutError.new("Timed out", request_id: "req_123", timeout_seconds: 60)
    assert_equal "req_123", error.request_id
    assert_equal 60, error.timeout_seconds
    assert_match(/req_123/, error.message)
    assert_match(/60s/, error.message)
  end

  test "abort_error_default_message" do
    error = ClaudeAgent::AbortError.new
    assert_match(/aborted/, error.message)
  end

  test "abort_error_custom_message" do
    error = ClaudeAgent::AbortError.new("User cancelled")
    assert_equal "User cancelled", error.message
  end

  test "abort_error_inherits_from_error" do
    error = ClaudeAgent::AbortError.new
    assert_kind_of ClaudeAgent::Error, error
  end
end
