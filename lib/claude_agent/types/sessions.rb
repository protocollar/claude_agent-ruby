# frozen_string_literal: true

module ClaudeAgent
  # Session metadata returned by list_sessions (TypeScript SDK parity: SDKSessionInfo)
  #
  # @example
  #   session = SessionInfo.new(
  #     session_id: "abc-123",
  #     summary: "Fix login bug",
  #     last_modified: 1706000000000,
  #     file_size: 4096,
  #     custom_title: "Login fix",
  #     first_prompt: "Help me fix the login page",
  #     git_branch: "fix/login",
  #     cwd: "/Users/dev/myapp"
  #   )
  #
  class SessionInfo < ImmutableRecord
    attribute :session_id
    attribute :summary
    attribute :last_modified
    attribute :file_size
    attribute :custom_title, default: nil
    attribute :first_prompt, default: nil
    attribute :git_branch, default: nil
    attribute :cwd, default: nil
    attribute :tag, default: nil
    attribute :created_at, default: nil
  end

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

  # Result of forking a session (TypeScript SDK v0.2.76 parity)
  #
  # @example
  #   result = ClaudeAgent.fork_session("abc-123")
  #   puts result.session_id  # => new UUID
  #
  class ForkSessionResult < ImmutableRecord
    attribute :session_id
  end
end
