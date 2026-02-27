# frozen_string_literal: true

module ClaudeAgent
  # Mutable wrapper around a ToolUseBlock for real-time status tracking.
  #
  # Unlike {ToolActivity} (immutable, built after a turn completes),
  # LiveToolActivity tracks status changes as they happen — running,
  # done, or error — making it suitable for live UIs.
  #
  # @example
  #   activity = LiveToolActivity.new(tool_use)
  #   activity.running?  # => true
  #   activity.elapsed   # => nil
  #
  #   activity.update_elapsed(2.5)
  #   activity.elapsed   # => 2.5
  #
  #   activity.complete!(tool_result)
  #   activity.done?     # => true
  #   activity.elapsed   # => 2.5 (preserved from progress)
  #
  class LiveToolActivity
    attr_reader :tool_use, :tool_result, :status, :started_at, :elapsed

    # @param tool_use [ToolUseBlock, ServerToolUseBlock] The tool use block
    def initialize(tool_use)
      @tool_use = tool_use
      @tool_result = nil
      @status = :running
      @started_at = Time.now
      @elapsed = nil
    end

    # Tool use ID
    # @return [String]
    def id
      tool_use.id
    end

    # Tool name
    # @return [String]
    def name
      tool_use.name
    end

    # Tool input
    # @return [Hash]
    def input
      tool_use.input
    end

    # Human-readable label (delegates to ToolUseBlock#display_label)
    # @return [String]
    def display_label
      tool_use.display_label
    end

    # Detailed summary (delegates to ToolUseBlock#summary)
    # @param max [Integer] Maximum length
    # @return [String]
    def summary(max: 60)
      tool_use.summary(max: max)
    end

    # File path if this is a file-based tool
    # @return [String, nil]
    def file_path
      tool_use.file_path
    end

    # Mark the tool as complete with its result.
    #
    # Transitions status to :done or :error based on the result.
    # Calculates elapsed time from started_at if not already set by progress updates.
    #
    # @param result [ToolResultBlock, ServerToolResultBlock] The tool result
    # @return [void]
    def complete!(result)
      @tool_result = result
      @status = result.is_error ? :error : :done
      @elapsed ||= Time.now - @started_at
    end

    # Update elapsed time from a ToolProgressMessage.
    #
    # @param seconds [Float] Elapsed time in seconds
    # @return [void]
    def update_elapsed(seconds)
      @elapsed = seconds
    end

    # Whether the tool is currently running.
    # @return [Boolean]
    def running?
      @status == :running
    end

    # Whether the tool completed successfully.
    # @return [Boolean]
    def done?
      @status == :done
    end

    # Whether the tool completed with an error.
    # @return [Boolean]
    def error?
      @status == :error
    end

    # Whether the tool execution is complete (done or error).
    # @return [Boolean]
    def complete?
      @status == :done || @status == :error
    end

    # @return [Hash]
    def to_h
      {
        id: id,
        name: name,
        status: @status,
        elapsed: @elapsed,
        started_at: @started_at
      }
    end

    def inspect
      parts = [ "#<#{self.class}" ]
      parts << "id=#{id}"
      parts << "name=#{name}"
      parts << "status=#{@status}"
      parts << "elapsed=#{@elapsed}s" if @elapsed
      "#{parts.join(" ")}>"
    end
  end
end
