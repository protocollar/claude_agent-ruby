# frozen_string_literal: true

module ClaudeAgent
  # Sandbox configuration for command execution (TypeScript SDK parity)
  #
  # @example Basic sandbox
  #   sandbox = SandboxSettings.new(enabled: true)
  #
  # @example With network config
  #   sandbox = SandboxSettings.new(
  #     enabled: true,
  #     auto_allow_bash_if_sandboxed: true,
  #     excluded_commands: ["docker"],
  #     network: SandboxNetworkConfig.new(allow_local_binding: true)
  #   )
  #
  # @example With custom ripgrep
  #   sandbox = SandboxSettings.new(
  #     enabled: true,
  #     ripgrep: SandboxRipgrepConfig.new(command: "/usr/local/bin/rg")
  #   )
  #
  class SandboxSettings < ImmutableRecord
    attribute :enabled, default: false
    attribute :auto_allow_bash_if_sandboxed, default: false
    attribute :excluded_commands, default: []
    attribute :allow_unsandboxed_commands, default: false
    attribute :network, default: nil
    attribute :ignore_violations, default: nil
    attribute :enable_weaker_nested_sandbox, default: false
    attribute :enable_weaker_network_isolation, default: false
    attribute :ripgrep, default: nil
    attribute :filesystem, default: nil

    def to_h
      result = { enabled: enabled }
      result[:autoAllowBashIfSandboxed] = auto_allow_bash_if_sandboxed if auto_allow_bash_if_sandboxed
      result[:excludedCommands] = excluded_commands unless excluded_commands.empty?
      result[:allowUnsandboxedCommands] = allow_unsandboxed_commands if allow_unsandboxed_commands
      result[:network] = network.to_h if network && !network.to_h.empty?
      result[:ignoreViolations] = ignore_violations.to_h if ignore_violations && !ignore_violations.to_h.empty?
      result[:enableWeakerNestedSandbox] = enable_weaker_nested_sandbox if enable_weaker_nested_sandbox
      result[:enableWeakerNetworkIsolation] = enable_weaker_network_isolation if enable_weaker_network_isolation
      result[:ripgrep] = ripgrep.to_h if ripgrep
      result[:filesystem] = filesystem.to_h if filesystem && !filesystem.to_h.empty?
      result
    end
  end
end
