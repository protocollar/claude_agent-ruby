# frozen_string_literal: true

require "open3"
require "json"
require "timeout"

module ClaudeAgent
  module Transport
    # Subprocess transport that communicates with Claude Code CLI
    #
    # This transport spawns the Claude Code CLI as a subprocess and
    # communicates via stdin/stdout using JSON Lines protocol.
    #
    # @example Basic usage
    #   transport = ClaudeAgent::Transport::Subprocess.new(options)
    #   transport.connect
    #   transport.write('{"type":"user","message":{"role":"user","content":"Hello"}}')
    #   transport.read_messages { |msg| puts msg }
    #   transport.close
    #
    class Subprocess < Base
      MINIMUM_CLI_VERSION = "2.0.0"
      DEFAULT_BUFFER_SIZE = 1_048_576 # 1MB
      VERSION_CHECK_TIMEOUT = 2

      attr_reader :options, :cli_path, :process

      # @param options [ClaudeAgent::Options, nil] Configuration options
      # @param cli_path [String, nil] Override path to Claude CLI
      def initialize(options: nil, cli_path: nil)
        super()
        @options = options || Options.new
        @cli_path = cli_path || @options.cli_path || find_cli_path
        @stdin = nil
        @stdout = nil
        @stderr = nil
        @wait_thread = nil
        @process = nil # Custom spawned process (SpawnedProcess)
        @connected = false
        @killed = false
        @buffer = +""
        @max_buffer_size = @options.max_buffer_size || DEFAULT_BUFFER_SIZE
        @mutex = Mutex.new
      end

      # Start the CLI subprocess
      # @param streaming [Boolean] Whether to use streaming mode
      # @param prompt [String, nil] Initial prompt for non-streaming mode
      # @return [void]
      def connect(streaming: true, prompt: nil)
        raise CLIConnectionError, "Already connected" if @connected

        check_cli_version! unless skip_version_check?

        cmd = build_command(streaming: streaming, prompt: prompt)
        env = @options.to_env

        # Build spawn options for custom spawn function support
        spawn_options = SpawnOptions.new(
          command: @cli_path,
          args: cmd.drop(1), # Remove command itself since it's in :command
          cwd: working_directory,
          env: env,
          abort_signal: @options.abort_signal
        )

        # Use custom spawn function if provided, otherwise use default
        spawn_func = @options.spawn_claude_code_process || DEFAULT_SPAWN

        if spawn_func
          @process = spawn_func.call(spawn_options)
          # Extract streams from process for compatibility
          if @process.respond_to?(:stdin)
            @stdin = @process.stdin
            @stdout = @process.stdout
            @stderr = @process.stderr
            @wait_thread = @process.wait_thread if @process.respond_to?(:wait_thread)
          else
            # Custom process - use wrapper methods
            @stdin = ProcessStdinWrapper.new(@process)
            @stdout = ProcessStdoutWrapper.new(@process)
            @stderr = nil # Custom processes handle stderr internally
            @wait_thread = nil
          end
        else
          # Fallback to direct Open3 spawn
          @stdin, @stdout, @stderr, @wait_thread = Open3.popen3(env, *cmd, chdir: working_directory)
        end

        @connected = true

        # Always start stderr reader to prevent pipe buffer from filling up
        start_stderr_reader if @stderr

        # For non-streaming mode with --print, close stdin immediately
        # The prompt is passed as command-line argument, not via stdin
        unless streaming
          if @process&.respond_to?(:close_stdin)
            @process.close_stdin
          elsif @stdin && !@stdin.closed?
            @stdin.close
          end
        end
      rescue Errno::ENOENT => e
        raise CLINotFoundError, "Claude CLI not found at '#{@cli_path}': #{e.message}"
      rescue => e
        close
        raise CLIConnectionError, "Failed to start CLI: #{e.message}"
      end

      # Write a JSON message to stdin
      # @param data [String] JSON string to write
      # @return [void]
      def write(data)
        raise CLIConnectionError, "Not connected" unless @connected
        raise CLIConnectionError, "stdin closed" unless @stdin && !@stdin.closed?

        @mutex.synchronize do
          @stdin.write(data)
          @stdin.write("\n") unless data.end_with?("\n")
          @stdin.flush
        end
      rescue Errno::EPIPE
        raise CLIConnectionError, "Broken pipe - CLI process may have terminated"
      end

      # Read and parse JSON messages from stdout
      # @yield [Hash] Parsed JSON messages
      # @return [Enumerator] If no block given
      def read_messages
        return enum_for(:read_messages) unless block_given?

        raise CLIConnectionError, "Not connected" unless @connected
        raise CLIConnectionError, "stdout closed" unless @stdout && !@stdout.closed?

        @stdout.each_line do |line|
          line = line.strip
          next if line.empty?

          begin
            message = JSON.parse(line)
            yield message
          rescue JSON::ParserError
            # Buffer partial JSON (in case of split lines)
            @buffer << line
            if @buffer.bytesize > @max_buffer_size
              raise JSONDecodeError.new("Buffer overflow while parsing JSON", raw_content: @buffer[0..500])
            end

            # Try to parse buffer
            begin
              message = JSON.parse(@buffer)
              @buffer = +""
              yield message
            rescue JSON::ParserError
              # Keep buffering
            end
          end
        end
      end

      # Close stdin to signal end of input
      # @return [void]
      def end_input
        return unless @stdin && !@stdin.closed?

        @mutex.synchronize do
          @stdin.close
        end
      end

      # Close all streams and wait for process to exit
      # @return [Integer, nil] Exit status
      def close
        # Use custom process close if available
        if @process&.respond_to?(:close)
          @process.close
          exit_status = @process.exit_status if @process.respond_to?(:exit_status)
          @connected = false
          @process = nil
          @stdin = @stdout = @stderr = @wait_thread = nil
          return exit_status
        end

        @mutex.synchronize do
          @stdin&.close unless @stdin&.closed?
          @stdout&.close unless @stdout&.closed?
          @stderr&.close unless @stderr&.closed?
        end

        exit_status = @wait_thread&.value&.exitstatus
        @connected = false
        @stdin = @stdout = @stderr = @wait_thread = nil

        exit_status
      end

      # Check if transport is ready
      # @return [Boolean]
      def ready?
        @connected && @stdin && !@stdin.closed? && @stdout && !@stdout.closed?
      end

      # Check if transport is connected
      # @return [Boolean]
      def connected?
        @connected
      end

      # Get the exit status of the CLI process
      # @return [Integer, nil]
      def exit_status
        return @process.exit_status if @process&.respond_to?(:exit_status)

        @wait_thread&.value&.exitstatus
      end

      # Check if the CLI process is still running
      # @return [Boolean]
      def running?
        return @process.running? if @process&.respond_to?(:running?)

        @wait_thread&.alive? || false
      end

      # Check if the CLI process was killed externally
      # @return [Boolean]
      def killed?
        @killed || (@wait_thread && !@wait_thread.alive? && !@connected)
      end

      # Terminate the CLI process gracefully (SIGTERM)
      # @param timeout [Numeric] Seconds to wait before force kill
      # @return [void]
      def terminate(timeout: 5)
        # Use custom process terminate if available
        if @process&.respond_to?(:terminate)
          @process.terminate(timeout: timeout)
          return
        end

        return unless @wait_thread&.alive?

        pid = nil
        @mutex.synchronize do
          pid = @wait_thread&.pid
        end

        return unless pid

        begin
          Process.kill("TERM", pid)
        rescue Errno::ESRCH, Errno::EPERM
          # Process already dead or no permission
          return
        end

        # Wait for graceful shutdown
        unless @wait_thread.join(timeout)
          kill
        end
      end

      # Force kill the CLI process (SIGKILL)
      # @return [void]
      def kill
        # Use custom process kill if available
        if @process&.respond_to?(:kill)
          @mutex.synchronize { @killed = true }
          @process.kill
          return
        end

        return unless @wait_thread&.alive?

        pid = nil
        @mutex.synchronize do
          pid = @wait_thread&.pid
          @killed = true
        end

        return unless pid

        begin
          Process.kill("KILL", pid)
        rescue Errno::ESRCH, Errno::EPERM
          # Process already dead or no permission
        end
      end

      private

      def find_cli_path
        # Check common locations
        paths = [
          `which claude 2>/dev/null`.strip,
          "/usr/local/bin/claude",
          "/opt/homebrew/bin/claude",
          File.expand_path("~/.local/bin/claude")
        ]

        paths.find { |p| !p.empty? && File.executable?(p) } || "claude"
      end

      def check_cli_version!
        version_output = `#{@cli_path} -v 2>&1`.strip
        # Parse version like "claude 2.1.0" or just "2.1.0"
        version_match = version_output.match(/(\d+\.\d+\.\d+)/)

        unless version_match
          raise CLIVersionError.new(nil)
        end

        found_version = version_match[1]
        unless version_satisfies?(found_version, MINIMUM_CLI_VERSION)
          raise CLIVersionError.new(found_version)
        end
      rescue Errno::ENOENT
        raise CLINotFoundError
      rescue Errno::ETIMEDOUT, Timeout::Error
        # Skip version check on timeout
      end

      def version_satisfies?(found, minimum)
        found_parts = found.split(".").map(&:to_i)
        minimum_parts = minimum.split(".").map(&:to_i)

        found_parts.zip(minimum_parts).each do |f, m|
          f ||= 0
          m ||= 0
          return true if f > m
          return false if f < m
        end

        true
      end

      def skip_version_check?
        ENV["CLAUDE_AGENT_SDK_SKIP_VERSION_CHECK"] == "true"
      end

      def build_command(streaming:, prompt: nil)
        cmd = [ @cli_path ]

        # Add options-based arguments
        cmd.concat(@options.to_cli_args)

        # Output is always stream-json
        cmd.push("--output-format", "stream-json")

        # Input format only for streaming mode
        cmd.push("--input-format", "stream-json") if streaming

        # Always add verbose for better debugging (must be before -- separator)
        cmd.push("--verbose")

        # For non-streaming mode, add prompt as positional argument after --
        if !streaming && prompt
          cmd.push("--print")
          cmd.push("--")
          cmd.push(prompt)
        end

        cmd
      end

      def working_directory
        dir = @options.cwd&.to_s
        (dir && Dir.exist?(dir)) ? dir : Dir.pwd
      end

      def start_stderr_reader
        Thread.new do
          @stderr.each_line do |line|
            # Call callback if provided, otherwise just drain
            @options.stderr_callback&.call(line.chomp)
          rescue
            # Ignore callback errors
          end
        rescue IOError
          # Stream closed, exit thread
        end
      end
    end

    # Wrapper for custom process stdin to match IO interface
    # @api private
    class ProcessStdinWrapper
      def initialize(process)
        @process = process
        @closed = false
      end

      def write(data)
        @process.write(data)
      end

      def flush
        # Custom processes handle their own flushing
      end

      def close
        @process.close_stdin
        @closed = true
      end

      def closed?
        @closed
      end
    end

    # Wrapper for custom process stdout to match IO interface
    # @api private
    class ProcessStdoutWrapper
      def initialize(process)
        @process = process
      end

      def each_line(&block)
        @process.read_stdout(&block)
      end

      def close
        # Custom processes handle their own closing
      end

      def closed?
        !@process.running?
      end
    end
  end
end
