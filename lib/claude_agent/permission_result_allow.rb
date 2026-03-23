# frozen_string_literal: true

module ClaudeAgent
  # Result of a permission check (allow)
  #
  # @example Allow with modified input
  #   PermissionResultAllow.new(
  #     updated_input: input.merge("safe" => true),
  #     tool_use_id: "tool_123"
  #   )
  #
  class PermissionResultAllow < ImmutableRecord
    attribute :updated_input, default: nil
    attribute :updated_permissions, default: nil
    attribute :tool_use_id, default: nil

    def behavior
      "allow"
    end

    def to_h
      h = { behavior: "allow" }
      h[:updatedInput] = updated_input if updated_input
      h[:updatedPermissions] = updated_permissions&.map(&:to_h) if updated_permissions
      h[:toolUseID] = tool_use_id if tool_use_id
      h
    end
  end
end
