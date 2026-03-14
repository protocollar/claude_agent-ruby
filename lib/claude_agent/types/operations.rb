# frozen_string_literal: true

module ClaudeAgent
  # Task usage statistics for TaskNotificationMessage (TypeScript SDK parity)
  #
  # @example
  #   usage = TaskUsage.new(total_tokens: 5000, tool_uses: 3, duration_ms: 2500)
  #
  TaskUsage = Data.define(:total_tokens, :tool_uses, :duration_ms) do
    def initialize(total_tokens: 0, tool_uses: 0, duration_ms: 0)
      super
    end
  end

  # Permission denial information in result messages (TypeScript SDK parity)
  #
  SDKPermissionDenial = Data.define(:tool_name, :tool_use_id, :tool_input) do
    def initialize(tool_name:, tool_use_id:, tool_input:)
      super
    end
  end

  # Result of rewind_files() control method (TypeScript SDK parity)
  #
  # @example
  #   result = RewindFilesResult.new(
  #     can_rewind: true,
  #     files_changed: ["src/foo.rb", "src/bar.rb"],
  #     insertions: 10,
  #     deletions: 5
  #   )
  #
  RewindFilesResult = Data.define(:can_rewind, :error, :files_changed, :insertions, :deletions) do
    def initialize(can_rewind:, error: nil, files_changed: nil, insertions: nil, deletions: nil)
      super
    end
  end
end
