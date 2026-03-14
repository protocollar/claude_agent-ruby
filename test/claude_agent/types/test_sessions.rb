# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentTypesSessions < ActiveSupport::TestCase
  test "session_info_defined" do
    assert ClaudeAgent::SessionInfo
  end

  test "session_message_defined" do
    assert ClaudeAgent::SessionMessage
  end
end
