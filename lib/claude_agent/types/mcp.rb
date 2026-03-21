# frozen_string_literal: true

module ClaudeAgent
  # Return type for mcp_server_status() (TypeScript SDK parity)
  # Status values: "connected", "failed", "needs-auth", "pending"
  #
  # @example
  #   status = McpServerStatus.new(name: "filesystem", status: "connected", server_info: {name: "fs", version: "1.0"})
  #
  class McpServerStatus < ImmutableRecord
    attribute :name
    attribute :status
    attribute :server_info, default: nil
    attribute :error, default: nil
    attribute :config, default: nil
    attribute :scope, default: nil
    attribute :tools, default: nil
  end

  # Result of set_mcp_servers() control method (TypeScript SDK parity)
  #
  # @example
  #   result = McpSetServersResult.new(
  #     added: ["server1"],
  #     removed: ["old-server"],
  #     errors: {"server2" => "Connection failed"}
  #   )
  #
  class McpSetServersResult < ImmutableRecord
    attribute :added, default: []
    attribute :removed, default: []
    attribute :errors, default: {}
  end
end
