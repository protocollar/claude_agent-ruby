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
require_relative "claude_agent/query"
require_relative "claude_agent/client"
require_relative "claude_agent/conversation"
require_relative "claude_agent/session"            # V2 Session API (unstable)

module ClaudeAgent
  class << self
    # Create a new Conversation
    #
    # @see Conversation#initialize
    # @return [Conversation]
    def conversation(**kwargs)
      Conversation.new(**kwargs)
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
