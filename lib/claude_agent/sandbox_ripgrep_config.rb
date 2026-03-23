# frozen_string_literal: true

module ClaudeAgent
  # Custom ripgrep configuration for sandbox mode (TypeScript SDK parity)
  #
  # @example
  #   ripgrep = SandboxRipgrepConfig.new(
  #     command: "/usr/local/bin/rg",
  #     args: ["--hidden"]
  #   )
  #
  class SandboxRipgrepConfig < ImmutableRecord
    attribute :command
    attribute :args, default: nil

    def to_h
      result = { command: command }
      result[:args] = args if args
      result
    end
  end
end
