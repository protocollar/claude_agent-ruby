# frozen_string_literal: true

module ClaudeAgent
  # Permission update request
  #
  # @example Add rules
  #   PermissionUpdate.new(
  #     type: "addRules",
  #     rules: [{tool_name: "Read", behavior: "allow"}]
  #   )
  #
  class PermissionUpdate < ImmutableRecord
    attribute :type
    attribute :rules, default: nil
    attribute :behavior, default: nil
    attribute :mode, default: nil
    attribute :directories, default: nil
    attribute :destination, default: nil

    def to_h
      h = { type: type }
      h[:rules] = rules.map { |r| normalize_rule(r) } if rules
      h[:behavior] = behavior if behavior
      h[:mode] = mode if mode
      h[:directories] = directories if directories
      h[:destination] = destination if destination
      h
    end

    private

    def normalize_rule(rule)
      return rule unless rule.is_a?(Hash)

      # Convert snake_case to camelCase
      # Note: behavior is NOT part of PermissionRuleValue per TypeScript SDK
      {
        toolName: rule[:tool_name] || rule[:toolName],
        ruleContent: rule[:rule_content] || rule[:ruleContent]
      }.compact
    end
  end
end
