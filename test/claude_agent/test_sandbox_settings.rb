# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentSandboxSettings < ActiveSupport::TestCase
  # --- SandboxNetworkConfig ---

  test "sandbox_network_config" do
    config = ClaudeAgent::SandboxNetworkConfig.new(
      allowed_domains: [ "api.example.com", "github.com" ],
      allow_local_binding: true,
      allow_unix_sockets: [ "/var/run/docker.sock" ],
      allow_all_unix_sockets: false,
      http_proxy_port: 8080,
      socks_proxy_port: 1080
    )
    assert_equal [ "api.example.com", "github.com" ], config.allowed_domains
    assert config.allow_local_binding
    assert_equal [ "/var/run/docker.sock" ], config.allow_unix_sockets
    refute config.allow_all_unix_sockets
    assert_equal 8080, config.http_proxy_port
    assert_equal 1080, config.socks_proxy_port
  end

  test "sandbox_network_config_defaults" do
    config = ClaudeAgent::SandboxNetworkConfig.new
    assert_equal [], config.allowed_domains
    refute config.allow_local_binding
    assert_equal [], config.allow_unix_sockets
    refute config.allow_all_unix_sockets
    assert_nil config.http_proxy_port
    assert_nil config.socks_proxy_port
  end

  test "sandbox_network_config_to_h" do
    config = ClaudeAgent::SandboxNetworkConfig.new(
      allowed_domains: [ "example.com" ],
      allow_local_binding: true,
      allow_unix_sockets: [ "/tmp/socket" ],
      http_proxy_port: 8080
    )
    h = config.to_h
    assert_equal [ "example.com" ], h[:allowedDomains]
    assert h[:allowLocalBinding]
    assert_equal [ "/tmp/socket" ], h[:allowUnixSockets]
    assert_equal 8080, h[:httpProxyPort]
    refute h.key?(:allowAllUnixSockets)
    refute h.key?(:socksProxyPort)
  end

  test "sandbox_network_config_to_h_empty" do
    config = ClaudeAgent::SandboxNetworkConfig.new
    h = config.to_h
    assert_equal({}, h)
  end

  # --- SandboxIgnoreViolations ---

  test "sandbox_ignore_violations" do
    ignore = ClaudeAgent::SandboxIgnoreViolations.new(
      file: [ "/tmp/*", "/var/log/*" ],
      network: [ "localhost:*", "127.0.0.1:*" ]
    )
    assert_equal [ "/tmp/*", "/var/log/*" ], ignore.file
    assert_equal [ "localhost:*", "127.0.0.1:*" ], ignore.network
  end

  test "sandbox_ignore_violations_defaults" do
    ignore = ClaudeAgent::SandboxIgnoreViolations.new
    assert_equal [], ignore.file
    assert_equal [], ignore.network
  end

  test "sandbox_ignore_violations_to_h" do
    ignore = ClaudeAgent::SandboxIgnoreViolations.new(
      file: [ "/tmp/*" ],
      network: [ "localhost:*" ]
    )
    h = ignore.to_h
    assert_equal [ "/tmp/*" ], h[:file]
    assert_equal [ "localhost:*" ], h[:network]
  end

  test "sandbox_ignore_violations_to_h_empty" do
    ignore = ClaudeAgent::SandboxIgnoreViolations.new
    assert_equal({}, ignore.to_h)
  end

  # --- SandboxRipgrepConfig ---

  test "sandbox_ripgrep_config" do
    config = ClaudeAgent::SandboxRipgrepConfig.new(
      command: "/usr/local/bin/rg",
      args: [ "--hidden", "--follow" ]
    )
    assert_equal "/usr/local/bin/rg", config.command
    assert_equal [ "--hidden", "--follow" ], config.args
  end

  test "sandbox_ripgrep_config_without_args" do
    config = ClaudeAgent::SandboxRipgrepConfig.new(command: "/opt/bin/rg")
    assert_equal "/opt/bin/rg", config.command
    assert_nil config.args
  end

  test "sandbox_ripgrep_config_to_h" do
    config = ClaudeAgent::SandboxRipgrepConfig.new(
      command: "/usr/bin/rg",
      args: [ "--no-ignore" ]
    )
    h = config.to_h
    assert_equal "/usr/bin/rg", h[:command]
    assert_equal [ "--no-ignore" ], h[:args]
  end

  test "sandbox_ripgrep_config_to_h_without_args" do
    config = ClaudeAgent::SandboxRipgrepConfig.new(command: "/usr/bin/rg")
    h = config.to_h
    assert_equal({ command: "/usr/bin/rg" }, h)
    refute h.key?(:args)
  end

  # --- SandboxSettings ---

  test "sandbox_settings" do
    sandbox = ClaudeAgent::SandboxSettings.new(
      enabled: true,
      auto_allow_bash_if_sandboxed: true,
      excluded_commands: [ "docker", "kubectl" ],
      allow_unsandboxed_commands: false
    )
    assert sandbox.enabled
    assert sandbox.auto_allow_bash_if_sandboxed
    assert_equal [ "docker", "kubectl" ], sandbox.excluded_commands
    refute sandbox.allow_unsandboxed_commands
  end

  test "sandbox_settings_defaults" do
    sandbox = ClaudeAgent::SandboxSettings.new
    refute sandbox.enabled
    refute sandbox.auto_allow_bash_if_sandboxed
    assert_equal [], sandbox.excluded_commands
    refute sandbox.allow_unsandboxed_commands
    assert_nil sandbox.network
    assert_nil sandbox.ignore_violations
    refute sandbox.enable_weaker_nested_sandbox
    assert_nil sandbox.ripgrep
  end

  test "sandbox_settings_with_network" do
    network = ClaudeAgent::SandboxNetworkConfig.new(
      allowed_domains: [ "api.example.com" ],
      allow_local_binding: true
    )
    sandbox = ClaudeAgent::SandboxSettings.new(
      enabled: true,
      network: network
    )
    assert_equal network, sandbox.network
    assert_equal [ "api.example.com" ], sandbox.network.allowed_domains
  end

  test "sandbox_settings_with_ignore_violations" do
    ignore = ClaudeAgent::SandboxIgnoreViolations.new(file: [ "/tmp/*" ])
    sandbox = ClaudeAgent::SandboxSettings.new(
      enabled: true,
      ignore_violations: ignore
    )
    assert_equal ignore, sandbox.ignore_violations
    assert_equal [ "/tmp/*" ], sandbox.ignore_violations.file
  end

  test "sandbox_settings_with_ripgrep" do
    ripgrep = ClaudeAgent::SandboxRipgrepConfig.new(
      command: "/usr/local/bin/rg",
      args: [ "--hidden" ]
    )
    sandbox = ClaudeAgent::SandboxSettings.new(
      enabled: true,
      ripgrep: ripgrep
    )
    assert_equal ripgrep, sandbox.ripgrep
    assert_equal "/usr/local/bin/rg", sandbox.ripgrep.command
  end

  test "sandbox_settings_with_weaker_nested_sandbox" do
    sandbox = ClaudeAgent::SandboxSettings.new(
      enabled: true,
      enable_weaker_nested_sandbox: true
    )
    assert sandbox.enable_weaker_nested_sandbox
  end

  test "sandbox_settings_to_h_basic" do
    sandbox = ClaudeAgent::SandboxSettings.new(enabled: true)
    assert_equal({ enabled: true }, sandbox.to_h)
  end

  test "sandbox_settings_to_h_with_all_options" do
    network = ClaudeAgent::SandboxNetworkConfig.new(
      allowed_domains: [ "example.com" ],
      allow_local_binding: true
    )
    ignore = ClaudeAgent::SandboxIgnoreViolations.new(file: [ "/tmp/*" ])
    ripgrep = ClaudeAgent::SandboxRipgrepConfig.new(command: "/usr/bin/rg")
    sandbox = ClaudeAgent::SandboxSettings.new(
      enabled: true,
      auto_allow_bash_if_sandboxed: true,
      excluded_commands: [ "docker" ],
      allow_unsandboxed_commands: true,
      network: network,
      ignore_violations: ignore,
      enable_weaker_nested_sandbox: true,
      ripgrep: ripgrep
    )
    h = sandbox.to_h
    assert h[:enabled]
    assert h[:autoAllowBashIfSandboxed]
    assert_equal [ "docker" ], h[:excludedCommands]
    assert h[:allowUnsandboxedCommands]
    assert_equal({ allowedDomains: [ "example.com" ], allowLocalBinding: true }, h[:network])
    assert_equal({ file: [ "/tmp/*" ] }, h[:ignoreViolations])
    assert h[:enableWeakerNestedSandbox]
    assert_equal({ command: "/usr/bin/rg" }, h[:ripgrep])
  end

  test "sandbox_settings_to_h_skips_empty_nested" do
    network = ClaudeAgent::SandboxNetworkConfig.new
    ignore = ClaudeAgent::SandboxIgnoreViolations.new
    sandbox = ClaudeAgent::SandboxSettings.new(
      enabled: true,
      network: network,
      ignore_violations: ignore
    )
    h = sandbox.to_h
    assert_equal({ enabled: true }, h)
    refute h.key?(:network)
    refute h.key?(:ignoreViolations)
  end
end
