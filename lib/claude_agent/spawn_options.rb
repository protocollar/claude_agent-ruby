# frozen_string_literal: true

module ClaudeAgent
  # Options passed to a spawn function for creating a Claude Code process (TypeScript SDK parity)
  #
  # This allows custom process creation for VMs, containers, remote execution, etc.
  #
  # @example
  #   options = SpawnOptions.new(
  #     command: "/usr/local/bin/claude",
  #     args: ["--output-format", "stream-json"],
  #     cwd: "/my/project",
  #     env: { "CLAUDE_CODE_ENTRYPOINT" => "sdk-rb" }
  #   )
  #
  class SpawnOptions < ImmutableRecord
    attribute :command
    attribute :args, default: []
    attribute :cwd, default: nil
    attribute :env, default: {}
    attribute :abort_signal, default: nil

    # Get the full command line as an array
    # @return [Array<String>]
    def to_command_array
      [ command, *args ]
    end
  end
end
