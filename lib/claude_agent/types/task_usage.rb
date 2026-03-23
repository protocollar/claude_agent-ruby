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
end
