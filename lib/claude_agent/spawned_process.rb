# frozen_string_literal: true

module ClaudeAgent
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
end
