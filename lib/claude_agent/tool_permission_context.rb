# frozen_string_literal: true

module ClaudeAgent
  # Context provided to can_use_tool callbacks (TypeScript SDK parity)
  #
  # @example
  #   context = ToolPermissionContext.new(
  #     permission_suggestions: [update1, update2],
  #     blocked_path: "/etc/passwd",
  #     decision_reason: "Path outside allowed directories",
  #     tool_use_id: "tool_123",
  #     agent_id: "agent_456",
  #     title: "Claude wants to read /etc/passwd",
  #     display_name: "Read file",
  #     signal: abort_signal
  #   )
  #
  class ToolPermissionContext < ImmutableRecord
    attribute :permission_suggestions, default: nil
    attribute :blocked_path, default: nil
    attribute :decision_reason, default: nil
    attribute :tool_use_id, default: nil
    attribute :agent_id, default: nil
    attribute :signal, default: nil
    attribute :description, default: nil
    attribute :title, default: nil
    attribute :display_name, default: nil
    attribute :request, default: nil
  end
end
