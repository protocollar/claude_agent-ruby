# frozen_string_literal: true

module ClaudeAgent
  # Task usage statistics for TaskNotificationMessage (TypeScript SDK parity)
  #
  # @example
  #   usage = TaskUsage.new(total_tokens: 5000, tool_uses: 3, duration_ms: 2500)
  #
  class TaskUsage < ImmutableRecord
    attribute :total_tokens, default: 0
    attribute :tool_uses, default: 0
    attribute :duration_ms, default: 0
  end

  # Permission denial information in result messages (TypeScript SDK parity)
  #
  class SDKPermissionDenial < ImmutableRecord
    attribute :tool_name
    attribute :tool_use_id
    attribute :tool_input
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
  class RewindFilesResult < ImmutableRecord
    attribute :can_rewind
    attribute :error, default: nil
    attribute :files_changed, default: nil
    attribute :insertions, default: nil
    attribute :deletions, default: nil
  end
end
