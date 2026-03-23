# frozen_string_literal: true

module ClaudeAgent
  # Configuration for ignoring specific sandbox violations (TypeScript SDK parity)
  #
  # @example
  #   ignore = SandboxIgnoreViolations.new(
  #     file: ["/tmp/*"],
  #     network: ["localhost:*"]
  #   )
  #
  class SandboxIgnoreViolations < ImmutableRecord
    attribute :file, default: []
    attribute :network, default: []

    def to_h
      result = {}
      result[:file] = file unless file.empty?
      result[:network] = network unless network.empty?
      result
    end
  end
end
