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
  SessionInfo = Data.define(
    :session_id,
    :summary,
    :last_modified,
    :file_size,
    :custom_title,
    :first_prompt,
    :git_branch,
    :cwd,
    :tag,
    :created_at
  ) do
    def initialize(session_id:, summary:, last_modified:, file_size:, custom_title: nil, first_prompt: nil, git_branch: nil, cwd: nil, tag: nil, created_at: nil)
      super
    end
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
  SessionMessage = Data.define(:type, :uuid, :session_id, :message, :parent_tool_use_id) do
    def initialize(type:, uuid:, session_id:, message:, parent_tool_use_id: nil)
      super
    end
  end

  # Result of forking a session (TypeScript SDK v0.2.76 parity)
  #
  # @example
  #   result = ClaudeAgent.fork_session("abc-123")
  #   puts result.session_id  # => new UUID
  #
  ForkSessionResult = Data.define(:session_id)
end
