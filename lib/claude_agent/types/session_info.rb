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
end
