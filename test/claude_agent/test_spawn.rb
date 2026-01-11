# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentSpawnOptions < ActiveSupport::TestCase
  test "spawn_options_initialization" do
    options = ClaudeAgent::SpawnOptions.new(
      command: "/usr/local/bin/claude",
      args: [ "--verbose" ],
      cwd: "/my/project",
      env: { "FOO" => "bar" }
    )

    assert_equal "/usr/local/bin/claude", options.command
    assert_equal [ "--verbose" ], options.args
    assert_equal "/my/project", options.cwd
    assert_equal({ "FOO" => "bar" }, options.env)
    assert_nil options.abort_signal
  end

  test "spawn_options_defaults" do
    options = ClaudeAgent::SpawnOptions.new(command: "claude")

    assert_equal "claude", options.command
    assert_equal [], options.args
    assert_nil options.cwd
    assert_equal({}, options.env)
  end

  test "spawn_options_with_abort_signal" do
    controller = ClaudeAgent::AbortController.new
    options = ClaudeAgent::SpawnOptions.new(
      command: "claude",
      abort_signal: controller.signal
    )

    assert_equal controller.signal, options.abort_signal
  end

  test "spawn_options_to_command_array" do
    options = ClaudeAgent::SpawnOptions.new(
      command: "/usr/bin/claude",
      args: [ "--verbose", "--output-format", "stream-json" ]
    )

    expected = [ "/usr/bin/claude", "--verbose", "--output-format", "stream-json" ]
    assert_equal expected, options.to_command_array
  end

  test "spawn_options_immutable" do
    options = ClaudeAgent::SpawnOptions.new(command: "claude")
    assert options.frozen?
  end
end

# Mock spawned process for testing
class MockSpawnedProcess
  include ClaudeAgent::SpawnedProcess

  attr_reader :written_data, :terminated, :killed, :closed
  attr_accessor :stdout_lines, :running

  def initialize
    @written_data = []
    @stdout_lines = []
    @terminated = false
    @killed = false
    @closed = false
    @running = true
    @stdin_closed = false
  end

  def write(data)
    @written_data << data
  end

  def read_stdout(&block)
    @stdout_lines.each(&block)
  end

  def read_stderr
    # Empty for mock
  end

  def close_stdin
    @stdin_closed = true
  end

  def stdin_closed?
    @stdin_closed
  end

  def terminate(timeout: 5)
    @terminated = true
    @running = false
  end

  def kill
    @killed = true
    @running = false
  end

  def running?
    @running
  end

  def exit_status
    @running ? nil : 0
  end

  def close
    @closed = true
    @running = false
  end
end

class TestClaudeAgentSpawnedProcess < ActiveSupport::TestCase
  test "mock_process_implements_interface" do
    process = MockSpawnedProcess.new

    # Verify all interface methods are available
    assert process.respond_to?(:write)
    assert process.respond_to?(:read_stdout)
    assert process.respond_to?(:read_stderr)
    assert process.respond_to?(:close_stdin)
    assert process.respond_to?(:terminate)
    assert process.respond_to?(:kill)
    assert process.respond_to?(:running?)
    assert process.respond_to?(:exit_status)
    assert process.respond_to?(:close)
  end

  test "mock_process_write" do
    process = MockSpawnedProcess.new
    process.write("hello\n")
    process.write("world\n")

    assert_equal [ "hello\n", "world\n" ], process.written_data
  end

  test "mock_process_read_stdout" do
    process = MockSpawnedProcess.new
    process.stdout_lines = [ "line1\n", "line2\n" ]

    lines = []
    process.read_stdout { |line| lines << line }

    assert_equal [ "line1\n", "line2\n" ], lines
  end

  test "mock_process_terminate" do
    process = MockSpawnedProcess.new
    assert process.running?

    process.terminate

    refute process.running?
    assert process.terminated
  end

  test "mock_process_kill" do
    process = MockSpawnedProcess.new
    process.kill

    refute process.running?
    assert process.killed
  end

  test "mock_process_exit_status" do
    process = MockSpawnedProcess.new
    assert_nil process.exit_status

    process.running = false
    assert_equal 0, process.exit_status
  end
end

class TestClaudeAgentLocalSpawnedProcess < ActiveSupport::TestCase
  test "local_process_spawn" do
    # Test with a simple echo command
    options = ClaudeAgent::SpawnOptions.new(
      command: "echo",
      args: [ "hello" ]
    )

    process = ClaudeAgent::LocalSpawnedProcess.spawn(options)
    assert process.respond_to?(:read_stdout)

    output = []
    process.read_stdout { |line| output << line.chomp }
    process.close

    assert_includes output, "hello"
  end

  test "local_process_write_and_read" do
    # Test with cat which echoes stdin to stdout
    options = ClaudeAgent::SpawnOptions.new(
      command: "cat"
    )

    process = ClaudeAgent::LocalSpawnedProcess.spawn(options)

    # Write data
    process.write("test line")
    process.close_stdin

    # Read output
    output = []
    process.read_stdout { |line| output << line.chomp }
    process.close

    assert_includes output, "test line"
  end

  test "local_process_running" do
    options = ClaudeAgent::SpawnOptions.new(
      command: "sleep",
      args: [ "0.1" ]
    )

    process = ClaudeAgent::LocalSpawnedProcess.spawn(options)
    assert process.running?

    process.close
    sleep 0.2
    refute process.running?
  end

  test "local_process_terminate" do
    options = ClaudeAgent::SpawnOptions.new(
      command: "sleep",
      args: [ "10" ]
    )

    process = ClaudeAgent::LocalSpawnedProcess.spawn(options)
    assert process.running?

    process.terminate(timeout: 1)
    refute process.running?
  end

  test "local_process_kill" do
    options = ClaudeAgent::SpawnOptions.new(
      command: "sleep",
      args: [ "10" ]
    )

    process = ClaudeAgent::LocalSpawnedProcess.spawn(options)
    assert process.running?

    process.kill
    sleep 0.1
    refute process.running?
  end
end

class TestClaudeAgentDefaultSpawn < ActiveSupport::TestCase
  test "default_spawn_returns_local_process" do
    options = ClaudeAgent::SpawnOptions.new(
      command: "echo",
      args: [ "test" ]
    )

    process = ClaudeAgent::DEFAULT_SPAWN.call(options)

    assert_kind_of ClaudeAgent::LocalSpawnedProcess, process
    process.close
  end
end

class TestClaudeAgentOptionsSpawnFunction < ActiveSupport::TestCase
  test "options_accepts_spawn_function" do
    custom_spawn = ->(opts) { MockSpawnedProcess.new }
    options = ClaudeAgent::Options.new(spawn_claude_code_process: custom_spawn)

    assert_equal custom_spawn, options.spawn_claude_code_process
  end

  test "options_spawn_function_nil_by_default" do
    options = ClaudeAgent::Options.new
    assert_nil options.spawn_claude_code_process
  end
end

class TestClaudeAgentSubprocessCustomSpawn < ActiveSupport::TestCase
  test "subprocess_uses_custom_spawn_function" do
    spawned_process = nil
    custom_spawn = ->(opts) {
      spawned_process = MockSpawnedProcess.new
      spawned_process.stdout_lines = [ '{"type":"result","subtype":"success"}' ]
      spawned_process
    }

    options = ClaudeAgent::Options.new(spawn_claude_code_process: custom_spawn)

    # Skip version check for testing
    ENV["CLAUDE_AGENT_SDK_SKIP_VERSION_CHECK"] = "true"

    transport = ClaudeAgent::Transport::Subprocess.new(options: options)
    transport.connect(streaming: true)

    assert_equal spawned_process, transport.process
    transport.close
  ensure
    ENV.delete("CLAUDE_AGENT_SDK_SKIP_VERSION_CHECK")
  end

  test "subprocess_write_uses_custom_process" do
    mock_process = MockSpawnedProcess.new
    mock_process.stdout_lines = []
    custom_spawn = ->(_) { mock_process }

    options = ClaudeAgent::Options.new(spawn_claude_code_process: custom_spawn)

    ENV["CLAUDE_AGENT_SDK_SKIP_VERSION_CHECK"] = "true"

    transport = ClaudeAgent::Transport::Subprocess.new(options: options)
    transport.connect(streaming: true)
    transport.write('{"type":"user"}')

    assert_includes mock_process.written_data.join, '{"type":"user"}'
    transport.close
  ensure
    ENV.delete("CLAUDE_AGENT_SDK_SKIP_VERSION_CHECK")
  end

  test "subprocess_terminate_uses_custom_process" do
    mock_process = MockSpawnedProcess.new
    custom_spawn = ->(_) { mock_process }

    options = ClaudeAgent::Options.new(spawn_claude_code_process: custom_spawn)

    ENV["CLAUDE_AGENT_SDK_SKIP_VERSION_CHECK"] = "true"

    transport = ClaudeAgent::Transport::Subprocess.new(options: options)
    transport.connect(streaming: true)
    transport.terminate

    assert mock_process.terminated
  ensure
    ENV.delete("CLAUDE_AGENT_SDK_SKIP_VERSION_CHECK")
  end

  test "subprocess_kill_uses_custom_process" do
    mock_process = MockSpawnedProcess.new
    custom_spawn = ->(_) { mock_process }

    options = ClaudeAgent::Options.new(spawn_claude_code_process: custom_spawn)

    ENV["CLAUDE_AGENT_SDK_SKIP_VERSION_CHECK"] = "true"

    transport = ClaudeAgent::Transport::Subprocess.new(options: options)
    transport.connect(streaming: true)
    transport.kill

    assert mock_process.killed
  ensure
    ENV.delete("CLAUDE_AGENT_SDK_SKIP_VERSION_CHECK")
  end

  test "subprocess_close_uses_custom_process" do
    mock_process = MockSpawnedProcess.new
    custom_spawn = ->(_) { mock_process }

    options = ClaudeAgent::Options.new(spawn_claude_code_process: custom_spawn)

    ENV["CLAUDE_AGENT_SDK_SKIP_VERSION_CHECK"] = "true"

    transport = ClaudeAgent::Transport::Subprocess.new(options: options)
    transport.connect(streaming: true)
    transport.close

    assert mock_process.closed
  ensure
    ENV.delete("CLAUDE_AGENT_SDK_SKIP_VERSION_CHECK")
  end
end
