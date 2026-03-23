# frozen_string_literal: true

module ClaudeAgent
  # Permission rule value (TypeScript SDK parity)
  # Note: behavior is on PermissionUpdate, not on individual rules
  #
  class PermissionRuleValue < ImmutableRecord
    attribute :tool_name, default: nil
    attribute :rule_content, default: nil

    def to_h
      {
        toolName: tool_name,
        ruleContent: rule_content
      }.compact
    end
  end
end
