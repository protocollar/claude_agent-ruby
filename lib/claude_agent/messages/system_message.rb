# frozen_string_literal: true

module ClaudeAgent
  # System message (internal events)
  #
  # @example
  #   msg = SystemMessage.new(subtype: "init", data: {version: "2.0.0"})
  #
  class SystemMessage < ImmutableRecord
    include Message

    attribute :subtype
    attribute :data

    def type
      :system
    end
  end
end
