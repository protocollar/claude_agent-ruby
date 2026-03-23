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
end
