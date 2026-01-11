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
  SandboxNetworkConfig = Data.define(
    :allowed_domains,
    :allow_local_binding,
    :allow_unix_sockets,
    :allow_all_unix_sockets,
    :http_proxy_port,
    :socks_proxy_port
  ) do
    def initialize(
      allowed_domains: [],
      allow_local_binding: false,
      allow_unix_sockets: [],
      allow_all_unix_sockets: false,
      http_proxy_port: nil,
      socks_proxy_port: nil
    )
      super
    end

    def to_h
      result = {}
      result[:allowedDomains] = allowed_domains unless allowed_domains.empty?
      result[:allowLocalBinding] = allow_local_binding if allow_local_binding
      result[:allowUnixSockets] = allow_unix_sockets unless allow_unix_sockets.empty?
      result[:allowAllUnixSockets] = allow_all_unix_sockets if allow_all_unix_sockets
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
  SandboxIgnoreViolations = Data.define(:file, :network) do
    def initialize(file: [], network: [])
      super
    end

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
  SandboxRipgrepConfig = Data.define(:command, :args) do
    def initialize(command:, args: nil)
      super
    end

    def to_h
      result = { command: command }
      result[:args] = args if args
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
  SandboxSettings = Data.define(
    :enabled,
    :auto_allow_bash_if_sandboxed,
    :excluded_commands,
    :allow_unsandboxed_commands,
    :network,
    :ignore_violations,
    :enable_weaker_nested_sandbox,
    :ripgrep
  ) do
    def initialize(
      enabled: false,
      auto_allow_bash_if_sandboxed: false,
      excluded_commands: [],
      allow_unsandboxed_commands: false,
      network: nil,
      ignore_violations: nil,
      enable_weaker_nested_sandbox: false,
      ripgrep: nil
    )
      super
    end

    def to_h
      result = { enabled: enabled }
      result[:autoAllowBashIfSandboxed] = auto_allow_bash_if_sandboxed if auto_allow_bash_if_sandboxed
      result[:excludedCommands] = excluded_commands unless excluded_commands.empty?
      result[:allowUnsandboxedCommands] = allow_unsandboxed_commands if allow_unsandboxed_commands
      result[:network] = network.to_h if network && !network.to_h.empty?
      result[:ignoreViolations] = ignore_violations.to_h if ignore_violations && !ignore_violations.to_h.empty?
      result[:enableWeakerNestedSandbox] = enable_weaker_nested_sandbox if enable_weaker_nested_sandbox
      result[:ripgrep] = ripgrep.to_h if ripgrep
      result
    end
  end
end
