# frozen_string_literal: true

module ClaudeAgent
  # Message from a session transcript returned by get_session_messages (TypeScript SDK v0.2.59 parity)
  #
  # @example
  #   msg = SessionMessage.new(
  #     type: "user",
  #     uuid: "abc-123",
  #     session_id: "def-456",
  #     message: { "role" => "user", "content" => [{ "type" => "text", "text" => "Hello" }] }
  #   )
  #
  class SessionMessage < ImmutableRecord
    attribute :type
    attribute :uuid
    attribute :session_id
    attribute :message
    attribute :parent_tool_use_id, default: nil
  end
end
