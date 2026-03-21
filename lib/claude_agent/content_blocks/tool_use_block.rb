# frozen_string_literal: true

require "uri"

module ClaudeAgent
  # Tool use request block
  #
  # @example
  #   block = ToolUseBlock.new(id: "tool_123", name: "Read", input: {file_path: "/tmp/file"})
  #   block.input[:file_path] # => "/tmp/file"
  #   block.name # => "Read"
  #
  class ToolUseBlock < ImmutableRecord
    attribute :id
    attribute :name
    attribute :input

    def type
      :tool_use
    end

    def to_h
      { type: "tool_use", id: id, name: name, input: input }
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

    # One-line human-readable label for the tool call.
    # @return [String]
    def display_label
      case name
      when "Read", "Write", "Edit", "NotebookEdit"
        path = file_path
        path ? "#{name} #{shorten_path(path)}" : name
      when "Bash"
        cmd = input[:command]
        cmd ? "Bash: #{truncate(cmd, 50)}" : "Bash"
      when "Grep"
        pattern = input[:pattern]
        pattern ? "Grep: #{pattern}" : "Grep"
      when "Glob"
        pattern = input[:pattern]
        pattern ? "Glob: #{pattern}" : "Glob"
      when "WebFetch"
        host = extract_host(input[:url])
        host ? "WebFetch: #{host}" : "WebFetch"
      when "WebSearch"
        query = input[:query]
        query ? "WebSearch: #{truncate(query, 50)}" : "WebSearch"
      when "Task"
        desc = input[:description]
        desc ? "Task: #{truncate(desc, 50)}" : "Task"
      else
        name
      end
    end

    # Detailed summary of the tool call, truncated to max chars.
    # @param max [Integer] maximum length before truncation
    # @return [String]
    def summary(max: 60)
      text = case name
      when "Read"
        path = file_path
        path ? "Read: #{path}" : "Read"
      when "Write"
        path = file_path
        if path
          size = content_size(input[:content])
          "Write: #{path} (#{size})"
        else
          "Write"
        end
      when "Edit"
        path = file_path
        if path
          old = input[:old_string]
          lines = old ? old.count("\n") + 1 : 0
          "Edit: #{path} replacing #{lines} line(s)"
        else
          "Edit"
        end
      when "Bash"
        cmd = input[:command]
        cmd ? "Bash: #{cmd}" : "Bash"
      when "Grep"
        pattern = input[:pattern]
        path = input[:path]
        glob = input[:glob]
        parts = [ "Grep: #{pattern}" ]
        parts << "in #{path}" if path
        parts << "(#{glob})" if glob
        parts.join(" ")
      when "NotebookEdit"
        path = file_path
        path ? "NotebookEdit: #{path}" : "NotebookEdit"
      else
        "#{name}: #{input.inspect}"
      end

      truncate(text, max)
    end

    private

    def shorten_path(path)
      parts = path.to_s.split("/")
      parts.length > 2 ? parts.last(2).join("/") : path.to_s
    end

    def truncate(str, max)
      return str if str.length <= max
      "#{str[0, max]}..."
    end

    def extract_host(url)
      return nil if url.nil?
      URI.parse(url.to_s).host
    rescue URI::InvalidURIError
      nil
    end

    def content_size(content)
      return "empty" if content.nil? || content.empty?
      lines = content.count("\n") + 1
      lines == 1 ? "1 line" : "#{lines} lines"
    end
  end
end
