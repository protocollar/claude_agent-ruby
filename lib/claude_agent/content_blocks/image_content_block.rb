# frozen_string_literal: true

module ClaudeAgent
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
  class ImageContentBlock < ImmutableRecord
    attribute :source

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
end
