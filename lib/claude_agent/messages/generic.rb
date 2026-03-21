# frozen_string_literal: true

module ClaudeAgent
  # Generic message for unknown/future protocol types
  #
  # Wraps unrecognized top-level message types so they can be inspected
  # without crashing the application. Supports dynamic field access via
  # `[]` and `method_missing`.
  #
  # @example
  #   msg = GenericMessage.new(message_type: "fancy_new", raw: { data: "hello" })
  #   msg.type       # => :fancy_new
  #   msg[:data]     # => "hello"
  #   msg.data       # => "hello"
  #   msg.to_h       # => { data: "hello" }
  #
  class GenericMessage < ImmutableRecord
    attribute :message_type
    attribute :raw

    def type
      message_type&.to_sym || :unknown
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
