# frozen_string_literal: true

require "open3"

module ClaudeAgent
  # Options passed to a spawn function for creating a Claude Code process (TypeScript SDK parity)
  #
  # This allows custom process creation for VMs, containers, remote execution, etc.
  #
  # @example
  #   options = SpawnOptions.new(
  #     command: "/usr/local/bin/claude",
  #     args: ["--output-format", "stream-json"],
  #     cwd: "/my/project",
  #     env: { "CLAUDE_CODE_ENTRYPOINT" => "sdk-rb" }
  #   )
  #
  SpawnOptions = Data.define(:command, :args, :cwd, :env, :abort_signal) do
    def initialize(command:, args: [], cwd: nil, env: {}, abort_signal: nil)
      super
    end

    # Get the full command line as an array
    # @return [Array<String>]
    def to_command_array
      [ command, *args ]
    end
  end

  # Interface for spawned process (TypeScript SDK parity)
  #
  # Custom spawn functions must return an object that responds to these methods.
  # This allows wrapping SSH connections, Docker exec, VM instances, etc.
  #
  # @abstract Implement all methods for custom process types
  #
  module SpawnedProcess
    # Write data to process stdin
    # @param data [String] Data to write
    # @return [void]
    def write(data)
      raise NotImplementedError
    end

    # Read from process stdout
    # @yield [String] Lines from stdout
    # @return [void]
    def read_stdout
      raise NotImplementedError
    end

    # Read from process stderr
    # @yield [String] Lines from stderr
    # @return [void]
    def read_stderr
      raise NotImplementedError
    end

    # Close stdin to signal end of input
    # @return [void]
    def close_stdin
      raise NotImplementedError
    end

    # Terminate the process gracefully (SIGTERM equivalent)
    # @param timeout [Numeric] Seconds to wait before force kill
    # @return [void]
    def terminate(timeout: 5)
      raise NotImplementedError
    end

    # Force kill the process (SIGKILL equivalent)
    # @return [void]
    def kill
      raise NotImplementedError
    end

    # Check if process is still running
    # @return [Boolean]
    def running?
      raise NotImplementedError
    end

    # Get process exit status
    # @return [Integer, nil]
    def exit_status
      raise NotImplementedError
    end

    # Close all streams
    # @return [void]
    def close
      raise NotImplementedError
    end
  end

  # Local spawned process wrapping Open3.popen3 (TypeScript SDK parity)
  #
  # This is the default implementation used when no custom spawn function is provided.
  #
  # @example
  #   process = LocalSpawnedProcess.spawn(options)
  #   process.write('{"type":"user"}\n')
  #   process.read_stdout { |line| puts line }
  #   process.close
  #
  class LocalSpawnedProcess
    include SpawnedProcess

    attr_reader :pid, :stdin, :stdout, :stderr, :wait_thread

    # Spawn a new local process
    # @param spawn_options [SpawnOptions] Options for spawning
    # @return [LocalSpawnedProcess]
    def self.spawn(spawn_options)
      cmd = spawn_options.to_command_array
      env = spawn_options.env || {}
      cwd = spawn_options.cwd

      opts = {}
      opts[:chdir] = cwd if cwd && Dir.exist?(cwd)

      stdin, stdout, stderr, wait_thread = Open3.popen3(env, *cmd, **opts)

      new(stdin: stdin, stdout: stdout, stderr: stderr, wait_thread: wait_thread)
    end

    def initialize(stdin:, stdout:, stderr:, wait_thread:)
      @stdin = stdin
      @stdout = stdout
      @stderr = stderr
      @wait_thread = wait_thread
      @killed = false
      @mutex = Mutex.new
    end

    def write(data)
      @mutex.synchronize do
        return if @stdin.closed?

        @stdin.write(data)
        @stdin.write("\n") unless data.end_with?("\n")
        @stdin.flush
      end
    rescue Errno::EPIPE
      # Process terminated
    end

    def read_stdout(&block)
      return enum_for(:read_stdout) unless block_given?

      @stdout.each_line(&block)
    rescue IOError
      # Stream closed
    end

    def read_stderr(&block)
      return enum_for(:read_stderr) unless block_given?

      @stderr.each_line(&block)
    rescue IOError
      # Stream closed
    end

    def close_stdin
      @mutex.synchronize do
        @stdin.close unless @stdin.closed?
      end
    end

    def terminate(timeout: 5)
      return unless running?

      pid = @wait_thread.pid
      begin
        Process.kill("TERM", pid)
      rescue Errno::ESRCH, Errno::EPERM
        return
      end

      unless @wait_thread.join(timeout)
        kill
      end
    end

    def kill
      return unless running?

      @mutex.synchronize { @killed = true }
      pid = @wait_thread.pid
      begin
        Process.kill("KILL", pid)
      rescue Errno::ESRCH, Errno::EPERM
        # Already dead
      end
    end

    def running?
      @wait_thread.alive?
    end

    def exit_status
      @wait_thread.value&.exitstatus
    end

    def killed?
      @killed
    end

    def close
      @mutex.synchronize do
        @stdin.close unless @stdin.closed?
        @stdout.close unless @stdout.closed?
        @stderr.close unless @stderr.closed?
      end
      @wait_thread.value
    end
  end

  # Default spawn function for local subprocess execution
  #
  # This lambda is used when no custom spawn_claude_code_process is provided.
  # It creates a LocalSpawnedProcess using Open3.popen3.
  #
  # @example Custom spawn for Docker
  #   custom_spawn = ->(opts) {
  #     docker_cmd = ["docker", "exec", "-i", "my-container", opts.command, *opts.args]
  #     DockerProcess.new(docker_cmd, env: opts.env)
  #   }
  #   options = ClaudeAgent::Options.new(spawn_claude_code_process: custom_spawn)
  #
  DEFAULT_SPAWN = ->(spawn_options) {
    LocalSpawnedProcess.spawn(spawn_options)
  }.freeze
end
