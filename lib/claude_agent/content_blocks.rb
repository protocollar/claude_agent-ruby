# frozen_string_literal: true

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
  #   block.name # => "Read"
  #
  ToolUseBlock = Data.define(:id, :name, :input) do
    def type
      :tool_use
    end

    def to_h
      { type: "tool_use", id: id, name: name, input: input }
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
  #
  # @example URL image
  #   block = ImageContentBlock.new(
  #     source: { type: "url", url: "https://example.com/image.png" }
  #   )
  #
  ImageContentBlock = Data.define(:source) do
    def type
      :image
    end

    # Get the media type if available
    # @return [String, nil]
    def media_type
      source.is_a?(Hash) ? (source[:media_type] || source["media_type"]) : nil
    end

    # Get the base64 data if available
    # @return [String, nil]
    def data
      source.is_a?(Hash) ? (source[:data] || source["data"]) : nil
    end

    # Get the URL if this is a URL-sourced image
    # @return [String, nil]
    def url
      source.is_a?(Hash) ? (source[:url] || source["url"]) : nil
    end

    # Get the source type (base64 or url)
    # @return [String, nil]
    def source_type
      source.is_a?(Hash) ? (source[:type] || source["type"]) : nil
    end

    def to_h
      { type: "image", source: source }
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
    ImageContentBlock
  ].freeze
end
