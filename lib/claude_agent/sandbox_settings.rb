# frozen_string_literal: true

module ClaudeAgent
  # Network-specific configuration for sandbox mode (TypeScript SDK parity)
  #
  # @example
  #   network = SandboxNetworkConfig.new(
  #     allow_local_binding: true,
  #     allow_unix_sockets: ["/var/run/docker.sock"],
  #     allowed_domains: ["api.example.com"]
  #   )
  #
  class SandboxNetworkConfig < ImmutableRecord
    attribute :allowed_domains, default: []
    attribute :allow_local_binding, default: false
    attribute :allow_unix_sockets, default: []
    attribute :allow_all_unix_sockets, default: false
    attribute :allow_managed_domains_only, default: false
    attribute :http_proxy_port, default: nil
    attribute :socks_proxy_port, default: nil

    def to_h
      result = {}
      result[:allowedDomains] = allowed_domains unless allowed_domains.empty?
      result[:allowLocalBinding] = allow_local_binding if allow_local_binding
      result[:allowUnixSockets] = allow_unix_sockets unless allow_unix_sockets.empty?
      result[:allowAllUnixSockets] = allow_all_unix_sockets if allow_all_unix_sockets
      result[:allowManagedDomainsOnly] = allow_managed_domains_only if allow_managed_domains_only
      result[:httpProxyPort] = http_proxy_port if http_proxy_port
      result[:socksProxyPort] = socks_proxy_port if socks_proxy_port
      result
    end
  end

  # Configuration for ignoring specific sandbox violations (TypeScript SDK parity)
  #
  # @example
  #   ignore = SandboxIgnoreViolations.new(
  #     file: ["/tmp/*"],
  #     network: ["localhost:*"]
  #   )
  #
  class SandboxIgnoreViolations < ImmutableRecord
    attribute :file, default: []
    attribute :network, default: []

    def to_h
      result = {}
      result[:file] = file unless file.empty?
      result[:network] = network unless network.empty?
      result
    end
  end

  # Custom ripgrep configuration for sandbox mode (TypeScript SDK parity)
  #
  # @example
  #   ripgrep = SandboxRipgrepConfig.new(
  #     command: "/usr/local/bin/rg",
  #     args: ["--hidden"]
  #   )
  #
  class SandboxRipgrepConfig < ImmutableRecord
    attribute :command
    attribute :args, default: nil

    def to_h
      result = { command: command }
      result[:args] = args if args
      result
    end
  end

  # Filesystem-specific configuration for sandbox mode (TypeScript SDK v0.2.77 parity)
  #
  # @example
  #   filesystem = SandboxFilesystemConfig.new(
  #     allow_write: ["/tmp/*"],
  #     deny_write: ["/etc/*"],
  #     deny_read: ["/secrets/*"],
  #     allow_read: ["/secrets/public/*"],
  #     allow_managed_read_paths_only: false
  #   )
  #
  class SandboxFilesystemConfig < ImmutableRecord
    attribute :allow_write, default: []
    attribute :deny_write, default: []
    attribute :deny_read, default: []
    attribute :allow_read, default: []
    attribute :allow_managed_read_paths_only, default: false

    def to_h
      result = {}
      result[:allowWrite] = allow_write unless allow_write.empty?
      result[:denyWrite] = deny_write unless deny_write.empty?
      result[:denyRead] = deny_read unless deny_read.empty?
      result[:allowRead] = allow_read unless allow_read.empty?
      result[:allowManagedReadPathsOnly] = allow_managed_read_paths_only if allow_managed_read_paths_only
      result
    end
  end

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
