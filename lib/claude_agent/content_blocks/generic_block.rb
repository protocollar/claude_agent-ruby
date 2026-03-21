# frozen_string_literal: true

module ClaudeAgent
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
  class GenericBlock < ImmutableRecord
    attribute :block_type
    attribute :raw

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
end
