# frozen_string_literal: true

require_relative "../integration_helper"

class TestIntegrationSpawn < IntegrationTestCase
  test "SpawnOptions type" do
    options = ClaudeAgent::SpawnOptions.new(
      command: "/usr/local/bin/claude",
      args: [ "--verbose", "--output-format", "stream-json" ],
      cwd: "/my/project",
      env: { "FOO" => "bar" }
    )

    assert_equal "/usr/local/bin/claude", options.command
    assert_equal [ "--verbose", "--output-format", "stream-json" ], options.args
    assert_equal "/my/project", options.cwd
    assert_equal({ "FOO" => "bar" }, options.env)

    cmd = options.to_command_array
    assert_equal "/usr/local/bin/claude", cmd[0]
    assert_equal "--verbose", cmd[1]

    controller = ClaudeAgent::AbortController.new
    options_with_signal = ClaudeAgent::SpawnOptions.new(
      command: "claude",
      abort_signal: controller.signal
    )
    assert_equal controller.signal, options_with_signal.abort_signal

    default_options = ClaudeAgent::SpawnOptions.new(command: "claude")
    assert_equal [], default_options.args
    assert_nil default_options.cwd
    assert_equal({}, default_options.env)
  end

  test "custom spawn function" do
    custom_spawn = ->(opts) { MockProcess.new }
    options = ClaudeAgent::Options.new(spawn_claude_code_process: custom_spawn)

    assert_equal custom_spawn, options.spawn_claude_code_process
    assert ClaudeAgent::DEFAULT_SPAWN.respond_to?(:call)

    spawn_opts = ClaudeAgent::SpawnOptions.new(
      command: "echo",
      args: [ "test" ]
    )
    process = ClaudeAgent::LocalSpawnedProcess.spawn(spawn_opts)

    assert process.respond_to?(:write)
    assert process.respond_to?(:read_stdout)
    assert process.respond_to?(:close_stdin)
    assert process.respond_to?(:terminate)
    assert process.respond_to?(:kill)
    assert process.respond_to?(:running?)
    assert process.respond_to?(:exit_status)
    assert process.respond_to?(:close)

    output = []
    process.read_stdout { |line| output << line.chomp }
    process.close

    assert_equal [ "test" ], output
  end

  test "UserMessageReplay type" do
    assert ClaudeAgent::MESSAGE_TYPES.include?(ClaudeAgent::UserMessageReplay)

    msg = ClaudeAgent::UserMessageReplay.new(
      content: "Hello",
      uuid: "msg-123",
      session_id: "sess-abc",
      parent_tool_use_id: "parent-456",
      is_replay: true,
      is_synthetic: true,
      tool_use_result: { "data" => "value" }
    )

    assert_equal :user, msg.type
    assert_equal "Hello", msg.content
    assert_equal "msg-123", msg.uuid
    assert msg.replay?, "Expected replay? to be true"
    assert msg.synthetic?, "Expected synthetic? to be true"
    assert_equal({ "data" => "value" }, msg.tool_use_result)

    default_msg = ClaudeAgent::UserMessageReplay.new(content: "test")
    assert default_msg.replay?, "Expected replay? to default to true"

    regular = ClaudeAgent::UserMessage.new(content: "test")
    assert !regular.replay?, "Expected regular UserMessage replay? to be false"
  end

  test "stream_input basic functionality" do
    client = ClaudeAgent::Client.new
    assert client.respond_to?(:stream_input), "Client should have stream_input method"

    options = ClaudeAgent::Options.new
    transport = ClaudeAgent::Transport::Subprocess.new(options: options)
    protocol = ClaudeAgent::ControlProtocol.new(transport: transport, options: options)

    assert protocol.respond_to?(:stream_input), "ControlProtocol should have stream_input method"
    assert protocol.respond_to?(:stream_conversation), "ControlProtocol should have stream_conversation method"
  end
end

# Simple mock process for testing
class MockProcess
  include ClaudeAgent::SpawnedProcess

  def write(data); end
  def read_stdout; end
  def read_stderr; end
  def close_stdin; end
  def terminate(timeout: 5); end
  def kill; end
  def running?; false; end
  def exit_status; 0; end
  def close; end
end
