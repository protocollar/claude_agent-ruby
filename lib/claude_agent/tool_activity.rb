# frozen_string_literal: true

module ClaudeAgent
  # A single tool execution in the conversation timeline.
  #
  # Pairs a ToolUseBlock with its ToolResultBlock and adds context
  # about which turn it occurred in and when.
  #
  # @example
  #   conversation.tool_activity.each do |activity|
  #     puts activity.display_label
  #     puts "  Turn: #{activity.turn_index}"
  #     puts "  Duration: #{activity.duration}s" if activity.duration
  #     puts "  Error!" if activity.error?
  #   end
  #
  class ToolActivity < ImmutableRecord
    attribute :tool_use
    attribute :turn_index
    attribute :tool_result, default: nil
    attribute :started_at, default: nil
    attribute :completed_at, default: nil

    # Tool name
    # @return [String]
    def name
      tool_use.name
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

    # Tool use ID
    # @return [String]
    def id
      tool_use.id
    end

    # Whether the tool produced an error result
    # @return [Boolean]
    def error?
      tool_result&.is_error == true
    end

    # Whether the tool execution is complete (has a result)
    # @return [Boolean]
    def complete?
      !tool_result.nil?
    end

    # Duration in seconds (nil if timing not available)
    # @return [Float, nil]
    def duration
      return nil unless started_at && completed_at
      completed_at - started_at
    end
  end
end
