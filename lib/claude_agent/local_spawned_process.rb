# frozen_string_literal: true

require "open3"

module ClaudeAgent
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
end
