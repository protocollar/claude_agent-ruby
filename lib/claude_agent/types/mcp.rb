# frozen_string_literal: true

module ClaudeAgent
  # Return type for mcp_server_status() (TypeScript SDK parity)
  # Status values: "connected", "failed", "needs-auth", "pending"
  #
  # @example
  #   status = McpServerStatus.new(name: "filesystem", status: "connected", server_info: {name: "fs", version: "1.0"})
  #
  McpServerStatus = Data.define(:name, :status, :server_info, :error, :config, :scope, :tools) do
    def initialize(name:, status:, server_info: nil, error: nil, config: nil, scope: nil, tools: nil)
      super
    end
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
  McpSetServersResult = Data.define(:added, :removed, :errors) do
    def initialize(added: [], removed: [], errors: {})
      super
    end
  end
end
