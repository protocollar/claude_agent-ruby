# frozen_string_literal: true

require_relative "../integration_helper"

class TestIntegrationToolActivityTracker < IntegrationTestCase
  # --- Conversation-level tracking ---

  test "tracker captures tool events during a turn" do
    started = []
    completed = []

    conversation = ClaudeAgent::Conversation.new(
      max_turns: 1,
      track_tools: true
    )
    conversation.tool_tracker.on_start { |entry| started << entry.name }
    conversation.tool_tracker.on_complete { |entry| completed << entry.name }

    conversation.say("Use the Bash tool to run: echo TRACKER_TEST")

    assert started.any?, "Expected at least one on_start callback"
    assert completed.any?, "Expected at least one on_complete callback"
  ensure
    conversation&.close
  end

  test "tracker resets after say completes" do
    conversation = ClaudeAgent::Conversation.new(
      max_turns: 1,
      track_tools: true
    )

    conversation.say("Use the Bash tool to run: echo RESET_TEST")

    assert conversation.tool_tracker.empty?, "Tracker should be empty after say returns"
  ensure
    conversation&.close
  end

  # --- Client-level tracking ---

  test "attach to client tracks tools without reset" do
    client = ClaudeAgent::Client.new(options: test_options)
    tracker = ClaudeAgent::ToolActivityTracker.attach(client)

    client.connect
    turn = client.send_and_receive("Use the Bash tool to run: echo CLIENT_TEST")

    if turn.tool_uses.any?
      assert tracker.any?, "Tracker should have entries when tools were used"
      assert tracker.all?(&:complete?), "All tracked tools should be complete"

      entry = tracker.first
      assert_instance_of ClaudeAgent::LiveToolActivity, entry
      assert entry.done? || entry.error?
      assert_not_nil entry.id
      assert_not_nil entry.name
    end
  ensure
    client&.disconnect
  end
end
