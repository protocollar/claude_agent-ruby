# frozen_string_literal: true

require "active_support/core_ext/string/inflections"
require "active_support/core_ext/hash/keys"

require_relative "claude_agent/version"
require_relative "claude_agent/logging"
require_relative "claude_agent/errors"
require_relative "claude_agent/types"              # TypeScript SDK parity types
require_relative "claude_agent/sandbox_settings"   # Sandbox configuration types
require_relative "claude_agent/abort_controller"   # Abort/cancel support (TypeScript SDK parity)
require_relative "claude_agent/spawn"              # Custom spawn support (TypeScript SDK parity)
require_relative "claude_agent/options"
require_relative "claude_agent/content_blocks"
require_relative "claude_agent/messages"
require_relative "claude_agent/message_parser"
require_relative "claude_agent/hooks"
require_relative "claude_agent/permissions"
require_relative "claude_agent/permission_request"
require_relative "claude_agent/permission_queue"
require_relative "claude_agent/control_protocol"
require_relative "claude_agent/transport/base"
require_relative "claude_agent/transport/subprocess"
require_relative "claude_agent/mcp/tool"
require_relative "claude_agent/mcp/server"
require_relative "claude_agent/cumulative_usage"
require_relative "claude_agent/event_handler"
require_relative "claude_agent/turn_result"
require_relative "claude_agent/tool_activity"
require_relative "claude_agent/live_tool_activity"
require_relative "claude_agent/tool_activity_tracker"
require_relative "claude_agent/query"
require_relative "claude_agent/client"
require_relative "claude_agent/conversation"
require_relative "claude_agent/session_paths"        # Shared session path infrastructure
require_relative "claude_agent/list_sessions"       # Session discovery (TypeScript SDK v0.2.53 parity)
require_relative "claude_agent/get_session_messages"    # Session transcript reading (TypeScript SDK v0.2.59 parity)
require_relative "claude_agent/session_message_relation" # Chainable message query object
require_relative "claude_agent/session_mutations"          # Session rename/tag mutations
require_relative "claude_agent/get_session_info"           # Single session lookup
require_relative "claude_agent/fork_session"               # Session forking (TypeScript SDK v0.2.76 parity)
require_relative "claude_agent/v2_session"                  # V2 Session API (unstable)
require_relative "claude_agent/session"                    # Session finder

module ClaudeAgent
  class << self
    # Create a new Conversation
    #
    # @see Conversation#initialize
    # @return [Conversation]
    def conversation(**kwargs)
      Conversation.new(**kwargs)
    end

    # List past sessions with metadata
    #
    # Reads session metadata directly from disk without spawning a CLI subprocess.
    # Returns SessionInfo objects sorted by last modified time (most recent first).
    #
    # @param dir [String, nil] Directory to scope sessions to (includes git worktrees).
    #   When nil, returns sessions from all projects.
    # @param limit [Integer, nil] Maximum number of sessions to return.
    # @param include_worktrees [Boolean] When dir is in a git repo, include sessions
    #   from all git worktree paths. Defaults to true.
    # @return [Array<SessionInfo>]
    def list_sessions(dir: nil, limit: nil, offset: nil, include_worktrees: true)
      ListSessions.call(dir: dir, limit: limit, offset: offset, include_worktrees: include_worktrees)
    end

    # Read messages from a past session's transcript
    #
    # Reads the session JSONL file from disk, reconstructs the main conversation
    # thread, and returns user/assistant messages with optional pagination.
    #
    # @param session_id [String] UUID of the session to read
    # @param dir [String, nil] Project directory to find the session in.
    #   When nil, searches all projects.
    # @param limit [Integer, nil] Maximum number of messages to return.
    # @param offset [Integer, nil] Number of messages to skip from the start.
    # @return [Array<SessionMessage>]
    def get_session_messages(session_id, dir: nil, limit: nil, offset: nil)
      GetSessionMessages.call(session_id, dir: dir, limit: limit, offset: offset)
    end

    # Rename a session by appending a custom-title entry to its file.
    #
    # @param session_id [String] UUID of the session to rename
    # @param title [String] New title
    # @param dir [String, nil] Project directory to scope the search
    # @return [void]
    def rename_session(session_id, title, dir: nil)
      SessionMutations.rename_session(session_id, title, dir: dir)
    end

    # Tag a session by appending a tag entry to its file.
    #
    # @param session_id [String] UUID of the session to tag
    # @param tag [String, nil] Tag value. Pass nil to clear.
    # @param dir [String, nil] Project directory to scope the search
    # @return [void]
    def tag_session(session_id, tag, dir: nil)
      SessionMutations.tag_session(session_id, tag, dir: dir)
    end

    # Look up a single session by ID.
    #
    # @param session_id [String] UUID of the session
    # @param dir [String, nil] Project directory to scope the search
    # @return [SessionInfo, nil]
    def get_session_info(session_id, dir: nil)
      GetSessionInfo.call(session_id, dir: dir)
    end

    # Fork a session by creating a new session file with remapped UUIDs.
    #
    # @param session_id [String] UUID of the source session
    # @param up_to_message_id [String, nil] Truncate at this message UUID (inclusive)
    # @param title [String, nil] Title for the forked session
    # @param dir [String, nil] Project directory to find the session in
    # @return [ForkSessionResult]
    def fork_session(session_id, up_to_message_id: nil, title: nil, dir: nil)
      ForkSession.call(session_id, up_to_message_id: up_to_message_id, title: title, dir: dir)
    end

    # Resume a previous Conversation by session ID
    #
    # @param session_id [String] Session ID to resume
    # @see Conversation.resume
    # @return [Conversation]
    def resume_conversation(session_id, **kwargs)
      Conversation.resume(session_id, **kwargs)
    end
  end
end
