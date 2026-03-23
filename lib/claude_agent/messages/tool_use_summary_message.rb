# frozen_string_literal: true

module ClaudeAgent
  # Tool use summary message (TypeScript SDK parity)
  #
  # Contains a summary of tool use for collapsed display.
  #
  # @example
  #   msg = ToolUseSummaryMessage.new(
  #     uuid: "msg-123",
  #     session_id: "session-abc",
  #     summary: "Read 3 files",
  #     preceding_tool_use_ids: ["tool-1", "tool-2", "tool-3"]
  #   )
  #
  class ToolUseSummaryMessage < ImmutableRecord
    include Message

    attribute :uuid
    attribute :session_id
    attribute :summary
    attribute :preceding_tool_use_ids, default: []

    def type
      :tool_use_summary
    end
  end
end
