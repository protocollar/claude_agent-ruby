# frozen_string_literal: true

module ClaudeAgent
  # Permission denial information in result messages (TypeScript SDK parity)
  #
  class SDKPermissionDenial < ImmutableRecord
    attribute :tool_name
    attribute :tool_use_id
    attribute :tool_input
  end
end
