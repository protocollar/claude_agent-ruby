# frozen_string_literal: true

require_relative "test_helper"

# Base class for integration tests that require the Claude Code CLI.
#
# Skip mechanism:
#   - Set INTEGRATION=true to run integration tests
#   - Without INTEGRATION=true, tests are skipped (not failed)
#
# Usage:
#   class TestIntegrationQuery < IntegrationTestCase
#     test "basic query" do
#       result = ClaudeAgent.query(prompt: "Hello")
#       assert result.success?
#     end
#   end
#
class IntegrationTestCase < ActiveSupport::TestCase
  def setup
    skip "Set INTEGRATION=true to run integration tests" unless run_integration?
    skip "Claude CLI not found in PATH" unless cli_available?
  end

  private

  def run_integration?
    ENV["INTEGRATION"] == "true"
  end

  def cli_available?
    system("which claude > /dev/null 2>&1")
  end

  # Helper to create options with sensible defaults for tests
  def test_options(**overrides)
    ClaudeAgent::Options.new(max_turns: 1, **overrides)
  end
end
