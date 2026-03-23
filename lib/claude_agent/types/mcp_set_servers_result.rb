# frozen_string_literal: true

module ClaudeAgent
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
