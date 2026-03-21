# frozen_string_literal: true

require "active_support/core_ext/string/inflections"
require "active_support/core_ext/hash/keys"

require_relative "claude_agent/version"
require_relative "claude_agent/logging"
require_relative "claude_agent/errors"
require_relative "claude_agent/immutable_record"    # Base class for all immutable value types
require_relative "claude_agent/types"              # TypeScript SDK parity types
require_relative "claude_agent/sandbox_settings"   # Sandbox configuration types
require_relative "claude_agent/abort_controller"   # Abort/cancel support (TypeScript SDK parity)
require_relative "claude_agent/spawn"              # Custom spawn support (TypeScript SDK parity)
require_relative "claude_agent/options"
require_relative "claude_agent/content_blocks"
require_relative "claude_agent/messages"
require_relative "claude_agent/message"              # Shared interface module for all message/block types
require_relative "claude_agent/permission_policy"    # Declarative permission DSL
require_relative "claude_agent/hooks/hook"
require_relative "claude_agent/hooks/hook_context"
require_relative "claude_agent/hooks/hook_input"
require_relative "claude_agent/hooks/hook_registry"
require_relative "claude_agent/message_parser"
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
require_relative "claude_agent/configuration"                # Stripe-style global config
require_relative "claude_agent/session"                    # Session finder

module ClaudeAgent
  require "forwardable"

  @config = Configuration.setup

  class << self
    extend Forwardable
    attr_reader :config

    # --- Tier 1 delegators (set once at boot) ---

    def_delegators :@config, :model, :model=,
                             :permission_mode, :permission_mode=,
                             :max_turns, :max_turns=,
                             :max_budget_usd, :max_budget_usd=,
                             :system_prompt, :system_prompt=,
                             :append_system_prompt, :append_system_prompt=,
                             :cli_path, :cli_path=,
                             :cwd, :cwd=,
                             :sandbox, :sandbox=,
                             :debug, :debug=,
                             :effort, :effort=,
                             :persist_session, :persist_session=,
                             :fallback_model, :fallback_model=

    # Block-based bulk configuration.
    #
    # @example
    #   ClaudeAgent.configure do |c|
    #     c.model = "opus"
    #     c.max_turns = 10
    #   end
    #
    # @yield [Configuration]
    # @return [void]
    def configure
      yield @config
    end

    # Reset configuration to defaults.
    # @return [Configuration]
    def reset_config!
      @config = Configuration.setup
    end

    # --- Primary entry points ---

    # One-shot query — the simple path returns a TurnResult.
    #
    # @param prompt [String] The prompt to send to Claude
    # @param options [Options, nil] Pre-built Options (bypasses Configuration merge)
    # @param kwargs Overrides merged with Configuration defaults
    # @yield [Message] Each message as it streams in (optional)
    # @return [TurnResult]
    #
    # @example Simple
    #   turn = ClaudeAgent.ask("What is 2+2?")
    #   puts turn.text
    #
    # @example With overrides
    #   turn = ClaudeAgent.ask("Fix the bug", model: "opus", max_turns: 5)
    #
    # @example With streaming
    #   turn = ClaudeAgent.ask("Explain Ruby") { |msg| print msg.text_content }
    #
    def ask(prompt, options: nil, **kwargs, &block)
      callbacks, config_overrides = extract_callbacks(kwargs)

      opts = options || @config.to_options(**config_overrides)
      events = build_events(callbacks)

      query_turn(prompt: prompt, options: opts, events: events, &block)
    end

    # Multi-turn conversation — block form auto-cleans, no block returns Conversation.
    #
    # @param kwargs Overrides merged with Configuration defaults
    # @yield [Conversation] Block form with auto-cleanup
    # @return [Conversation, Object] Conversation (no block) or block return value
    #
    # @example Block form
    #   ClaudeAgent.chat(model: "opus") do |c|
    #     c.say("Hello")
    #     c.say("Goodbye")
    #   end
    #
    # @example No block
    #   c = ClaudeAgent.chat(model: "opus")
    #   c.say("Hello")
    #   c.close
    #
    def chat(**kwargs, &block)
      # Merge global config defaults into kwargs for Conversation
      merged = merge_config_into_kwargs(kwargs)

      if block
        Conversation.open(**merged, &block)
      else
        Conversation.new(**merged)
      end
    end

    # Set a global permission policy.
    #
    # @yield [PermissionPolicy] DSL block
    # @return [void]
    def permissions(&block)
      @config.default_permissions = PermissionPolicy.new(&block)
    end

    # Set global hooks.
    #
    # @yield [HookRegistry] DSL block
    # @return [void]
    def hooks(&block)
      @config.default_hooks = HookRegistry.new(&block)
    end

    # Register a global MCP server.
    #
    # @param server [MCP::Server] Server instance
    # @return [void]
    def register_mcp_server(server)
      @config.default_mcp_servers[server.name] = server.to_config
    end

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

    private

    # Separate on_* callbacks from config overrides in kwargs.
    def extract_callbacks(kwargs)
      callbacks = {}
      config_overrides = {}

      kwargs.each do |key, value|
        if key.to_s.start_with?("on_") || key == :can_use_tool
          callbacks[key] = value
        else
          config_overrides[key] = value
        end
      end

      [ callbacks, config_overrides ]
    end

    # Build an EventHandler from on_* callback kwargs.
    def build_events(callbacks)
      return nil if callbacks.empty?

      events = EventHandler.new
      callbacks.each do |key, value|
        next unless value
        next if key == :can_use_tool

        event = Conversation::CALLBACK_ALIASES[key] || key.to_s.delete_prefix("on_").to_sym
        events.on(event, &value)
      end
      events.has_handlers? ? events : nil
    end

    # Merge global config defaults into Conversation kwargs.
    def merge_config_into_kwargs(kwargs)
      merged = {}

      # Apply config defaults for fields Conversation forwards to Options
      Configuration::ALL_FIELDS.each do |field|
        config_val = @config.public_send(field)
        merged[field] = config_val unless config_val.nil?
      end

      # Per-request kwargs override config
      merged.merge(kwargs)
    end
  end
end
