# frozen_string_literal: true

require_relative "../integration_helper"

class TestIntegrationTransport < IntegrationTestCase
  test "transport connected/ready states" do
    transport = ClaudeAgent::Transport::Subprocess.new(
      options: test_options
    )

    assert !transport.connected?
    assert !transport.ready?

    transport.connect(streaming: false, prompt: "test")
    assert transport.connected?

    transport.close
    assert !transport.connected?
  end

  test "error on invalid CLI path" do
    transport = ClaudeAgent::Transport::Subprocess.new(
      options: ClaudeAgent::Options.new,
      cli_path: "/nonexistent/path/to/claude"
    )

    assert_raises(
      ClaudeAgent::CLINotFoundError,
      ClaudeAgent::CLIConnectionError,
      ClaudeAgent::CLIVersionError
    ) do
      transport.connect(streaming: false, prompt: "test")
    end
  end
end
