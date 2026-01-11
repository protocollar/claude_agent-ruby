# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentTransportBase < ActiveSupport::TestCase
  test "base_transport_raises_not_implemented" do
    transport = ClaudeAgent::Transport::Base.new

    assert_raises(NotImplementedError) { transport.connect }
    assert_raises(NotImplementedError) { transport.write("data") }
    assert_raises(NotImplementedError) { transport.read_messages }
    assert_raises(NotImplementedError) { transport.end_input }
    assert_raises(NotImplementedError) { transport.close }
    assert_raises(NotImplementedError) { transport.ready? }
    assert_raises(NotImplementedError) { transport.connected? }
  end
end

class TestClaudeAgentTransportSubprocess < ActiveSupport::TestCase
  test "subprocess_initialization" do
    transport = ClaudeAgent::Transport::Subprocess.new
    refute transport.connected?
    refute transport.ready?
  end

  test "subprocess_with_options" do
    options = ClaudeAgent::Options.new(
      model: "claude-sonnet-4-5-20250514",
      max_turns: 5
    )
    transport = ClaudeAgent::Transport::Subprocess.new(options: options)
    assert_equal options, transport.options
  end

  test "subprocess_with_custom_cli_path" do
    transport = ClaudeAgent::Transport::Subprocess.new(cli_path: "/custom/path/claude")
    assert_equal "/custom/path/claude", transport.cli_path
  end

  test "subprocess_raises_when_not_connected" do
    transport = ClaudeAgent::Transport::Subprocess.new

    assert_raises(ClaudeAgent::CLIConnectionError) do
      transport.write("data")
    end

    assert_raises(ClaudeAgent::CLIConnectionError) do
      transport.read_messages.to_a
    end
  end

  test "subprocess_raises_when_already_connected" do
    transport = ClaudeAgent::Transport::Subprocess.new(cli_path: "echo")

    # Mock the connection
    transport.instance_variable_set(:@connected, true)

    assert_raises(ClaudeAgent::CLIConnectionError) do
      transport.connect
    end
  end
end
