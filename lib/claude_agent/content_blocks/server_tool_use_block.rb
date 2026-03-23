# frozen_string_literal: true

module ClaudeAgent
  # Server tool use block (for MCP servers)
  #
  class ServerToolUseBlock < ImmutableRecord
    include Message

    attribute :id
    attribute :name
    attribute :input
    attribute :server_name

    def type
      :server_tool_use
    end

    def to_h
      { type: "server_tool_use", id: id, name: name, input: input, server_name: server_name }
    end

    # Returns the file path for file-based tools, nil otherwise.
    # @return [String, nil]
    def file_path
      case name
      when "Read", "Write", "Edit"
        input[:file_path]
      when "NotebookEdit"
        input[:notebook_path]
      end
    end

    # One-line human-readable label with server context.
    # @return [String]
    def display_label
      server_name ? "#{server_name}/#{name}" : name
    end

    # Detailed summary with server context, truncated to max chars.
    # @param max [Integer] maximum length before truncation
    # @return [String]
    def summary(max: 60)
      label = display_label
      text = "#{label}: #{input.inspect}"
      truncate(text, max)
    end

    private

    def truncate(str, max)
      return str if str.length <= max
      "#{str[0, max]}..."
    end
  end
end
