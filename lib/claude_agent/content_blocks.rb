# frozen_string_literal: true

require "uri"

module ClaudeAgent
  # Text content block
  #
  # @example
  #   block = TextBlock.new(text: "Hello, world!")
  #   block.text # => "Hello, world!"
  #
  TextBlock = Data.define(:text) do
    def type
      :text
    end

    def to_h
      { type: "text", text: text }
    end
  end

  # Extended thinking content block
  #
  # @example
  #   block = ThinkingBlock.new(thinking: "Let me consider...", signature: "abc123")
  #   block.thinking # => "Let me consider..."
  #
  ThinkingBlock = Data.define(:thinking, :signature) do
    def type
      :thinking
    end

    def to_h
      { type: "thinking", thinking: thinking, signature: signature }
    end
  end

  # Tool use request block
  #
  # @example
  #   block = ToolUseBlock.new(id: "tool_123", name: "Read", input: {file_path: "/tmp/file"})
  #   block.input[:file_path] # => "/tmp/file"
  #   block.name # => "Read"
  #
  ToolUseBlock = Data.define(:id, :name, :input) do
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

  # Tool result block
  #
  # @example
  #   block = ToolResultBlock.new(tool_use_id: "tool_123", content: "file contents", is_error: false)
  #
  ToolResultBlock = Data.define(:tool_use_id, :content, :is_error) do
    def initialize(tool_use_id:, content: nil, is_error: nil)
      super
    end

    def type
      :tool_result
    end

    def to_h
      h = { type: "tool_result", tool_use_id: tool_use_id }
      h[:content] = content unless content.nil?
      h[:is_error] = is_error unless is_error.nil?
      h
    end
  end

  # Server tool use block (for MCP servers)
  #
  ServerToolUseBlock = Data.define(:id, :name, :input, :server_name) do
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

  # Server tool result block
  #
  ServerToolResultBlock = Data.define(:tool_use_id, :content, :is_error, :server_name) do
    def initialize(tool_use_id:, server_name:, content: nil, is_error: nil)
      super
    end

    def type
      :server_tool_result
    end

    def to_h
      h = { type: "server_tool_result", tool_use_id: tool_use_id, server_name: server_name }
      h[:content] = content unless content.nil?
      h[:is_error] = is_error unless is_error.nil?
      h
    end
  end

  # Image content block (TypeScript SDK parity)
  #
  # Supports both base64-encoded image data and URL sources.
  #
  # @example Base64 image
  #   block = ImageContentBlock.new(
  #     source: { type: "base64", media_type: "image/png", data: "..." }
  #   )
  #   block.source_type  # => "base64"
  #   block.media_type   # => "image/png"
  #
  # @example URL image
  #   block = ImageContentBlock.new(
  #     source: { type: "url", url: "https://example.com/image.png" }
  #   )
  #   block.url  # => "https://example.com/image.png"
  #
  ImageContentBlock = Data.define(:source) do
    def type
      :image
    end

    # Get the media type if available
    # @return [String, nil]
    def media_type
      source.is_a?(Hash) ? source[:media_type] : nil
    end

    # Get the base64 data if available
    # @return [String, nil]
    def data
      source.is_a?(Hash) ? source[:data] : nil
    end

    # Get the URL if this is a URL-sourced image
    # @return [String, nil]
    def url
      source.is_a?(Hash) ? source[:url] : nil
    end

    # Get the source type (base64 or url)
    # @return [String, nil]
    def source_type
      source.is_a?(Hash) ? source[:type] : nil
    end

    def to_h
      { type: "image", source: source }
    end
  end

  # Generic content block for unknown/future block types
  #
  # Wraps unrecognized content block types so they can be inspected
  # without losing type information. Supports dynamic field access via
  # `[]` and `method_missing`.
  #
  # @example
  #   block = GenericBlock.new(block_type: "citation", raw: { text: "ref", url: "https://example.com" })
  #   block.type     # => :citation
  #   block[:text]   # => "ref"
  #   block.url      # => "https://example.com"
  #   block.to_h     # => { text: "ref", url: "https://example.com" }
  #
  GenericBlock = Data.define(:block_type, :raw) do
    def type
      block_type&.to_sym || :unknown
    end

    def to_h
      raw
    end

    def [](key)
      raw[key]
    end

    def respond_to_missing?(name, include_private = false)
      raw.key?(name) || super
    end

    def method_missing(name, *args)
      return raw[name] if args.empty? && raw.key?(name)
      super
    end
  end

  # All content block types
  CONTENT_BLOCK_TYPES = [
    TextBlock,
    ThinkingBlock,
    ToolUseBlock,
    ToolResultBlock,
    ServerToolUseBlock,
    ServerToolResultBlock,
    ImageContentBlock,
    GenericBlock
  ].freeze
end
