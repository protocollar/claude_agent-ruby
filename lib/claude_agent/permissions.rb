# frozen_string_literal: true

module ClaudeAgent
  # Result of a permission check (allow)
  #
  # @example Allow with modified input
  #   PermissionResultAllow.new(
  #     updated_input: input.merge("safe" => true)
  #   )
  #
  PermissionResultAllow = Data.define(:updated_input, :updated_permissions) do
    def initialize(updated_input: nil, updated_permissions: nil)
      super
    end

    def behavior
      "allow"
    end

    def to_h
      h = { behavior: "allow" }
      h[:updatedInput] = updated_input if updated_input
      h[:updatedPermissions] = updated_permissions&.map { |p| p.respond_to?(:to_h) ? p.to_h : p } if updated_permissions
      h
    end
  end

  # Result of a permission check (deny)
  #
  # @example Deny with message
  #   PermissionResultDeny.new(
  #     message: "Operation not allowed",
  #     interrupt: true
  #   )
  #
  PermissionResultDeny = Data.define(:message, :interrupt) do
    def initialize(message: "", interrupt: false)
      super
    end

    def behavior
      "deny"
    end

    def to_h
      { behavior: "deny", message: message, interrupt: interrupt }
    end
  end

  # Valid permission update types
  PERMISSION_UPDATE_TYPES = %w[
    addRules
    replaceRules
    removeRules
    setMode
    addDirectories
    removeDirectories
  ].freeze

  # Permission update request
  #
  # @example Add rules
  #   PermissionUpdate.new(
  #     type: "addRules",
  #     rules: [{tool_name: "Read", behavior: "allow"}]
  #   )
  #
  PermissionUpdate = Data.define(
    :type,
    :rules,
    :behavior,
    :mode,
    :directories,
    :destination
  ) do
    def initialize(
      type:,
      rules: nil,
      behavior: nil,
      mode: nil,
      directories: nil,
      destination: nil
    )
      super
    end

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

  # Permission rule value (TypeScript SDK parity)
  # Note: behavior is on PermissionUpdate, not on individual rules
  #
  PermissionRuleValue = Data.define(:tool_name, :rule_content) do
    def initialize(tool_name: nil, rule_content: nil)
      super
    end

    def to_h
      {
        toolName: tool_name,
        ruleContent: rule_content
      }.compact
    end
  end

  # Valid permission update destinations (TypeScript SDK parity)
  PERMISSION_UPDATE_DESTINATIONS = %w[
    userSettings
    projectSettings
    localSettings
    session
    cliArg
  ].freeze

  # Context provided to can_use_tool callbacks (TypeScript SDK parity)
  #
  # @example
  #   context = ToolPermissionContext.new(
  #     permission_suggestions: [update1, update2],
  #     blocked_path: "/etc/passwd",
  #     decision_reason: "Path outside allowed directories",
  #     tool_use_id: "tool_123",
  #     agent_id: "agent_456"
  #   )
  #
  ToolPermissionContext = Data.define(
    :permission_suggestions,
    :blocked_path,
    :decision_reason,
    :tool_use_id,
    :agent_id
  ) do
    def initialize(
      permission_suggestions: nil,
      blocked_path: nil,
      decision_reason: nil,
      tool_use_id: nil,
      agent_id: nil
    )
      super
    end
  end
end
