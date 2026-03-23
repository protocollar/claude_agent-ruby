# frozen_string_literal: true

module ClaudeAgent
  # Result of a permission check (deny)
  #
  # @example Deny with message
  #   PermissionResultDeny.new(
  #     message: "Operation not allowed",
  #     interrupt: true,
  #     tool_use_id: "tool_123"
  #   )
  #
  class PermissionResultDeny < ImmutableRecord
    attribute :message, default: ""
    attribute :interrupt, default: false
    attribute :tool_use_id, default: nil

    def behavior
      "deny"
    end

    def to_h
      h = { behavior: "deny", message: message, interrupt: interrupt }
      h[:toolUseID] = tool_use_id if tool_use_id
      h
    end
  end
end
