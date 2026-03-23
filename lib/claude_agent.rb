# frozen_string_literal: true

require "zeitwerk"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/hash/keys"

module ClaudeAgent
  LOADER = Zeitwerk::Loader.for_gem
  LOADER.inflector.inflect(
    "mcp" => "MCP",
    "cli_not_found_error" => "CLINotFoundError",
    "cli_version_error" => "CLIVersionError",
    "cli_connection_error" => "CLIConnectionError",
    "json_decode_error" => "JSONDecodeError",
    "sdk_permission_denial" => "SDKPermissionDenial",
    "api_retry_message" => "APIRetryMessage",
    "v2_session" => "V2Session"
  )
  LOADER.collapse("#{__dir__}/claude_agent/content_blocks")
  LOADER.collapse("#{__dir__}/claude_agent/messages")
  LOADER.collapse("#{__dir__}/claude_agent/types")
  LOADER.collapse("#{__dir__}/claude_agent/hooks")
  LOADER.setup

  class << self
    # @return [Zeitwerk::Loader]
    def loader
      LOADER
    end
  end

  # --- Aggregate constants ---

  CONTENT_BLOCK_TYPES = [
    TextBlock,
    ThinkingBlock,
    ToolUseBlock,
    ToolResultBlock,
    ServerToolUseBlock,
    ServerToolResultBlock,
    ImageContentBlock,
    GenericBlock
  ].freeze

  MESSAGE_TYPES = [
    UserMessage,
    UserMessageReplay,
    AssistantMessage,
    SystemMessage,
    ResultMessage,
    StreamEvent,
    CompactBoundaryMessage,
    StatusMessage,
    ToolProgressMessage,
    HookResponseMessage,
    AuthStatusMessage,
    TaskNotificationMessage,
    HookStartedMessage,
    HookProgressMessage,
    ToolUseSummaryMessage,
    FilesPersistedEvent,
    TaskStartedMessage,
    TaskProgressMessage,
    RateLimitEvent,
    PromptSuggestionMessage,
    ElicitationCompleteMessage,
    LocalCommandOutputMessage,
    APIRetryMessage,
    GenericMessage
  ].freeze

  ASSISTANT_MESSAGE_ERROR_TYPES = %w[
    authentication_failed
    billing_error
    rate_limit
    invalid_request
    server_error
    unknown
    max_output_tokens
  ].freeze

  API_KEY_SOURCES = %w[user project org temporary oauth].freeze

  PERMISSION_UPDATE_TYPES = %w[
    addRules
    replaceRules
    removeRules
    setMode
    addDirectories
    removeDirectories
  ].freeze

  PERMISSION_UPDATE_DESTINATIONS = %w[
    userSettings
    projectSettings
    localSettings
    session
    cliArg
  ].freeze

  # --- Logging ---

  LOG_FORMATTER = proc do |severity, time, progname, msg|
    "[ClaudeAgent] [#{time.strftime("%H:%M:%S.%L")}] #{severity.ljust(5)} -- #{progname}: #{msg}\n"
  end

  # Default spawn function for local subprocess execution
  DEFAULT_SPAWN = ->(spawn_options) {
    LocalSpawnedProcess.spawn(spawn_options)
  }.freeze

  # --- Global configuration ---

  @config = Configuration.setup

  require "forwardable"

  class << self
    extend Forwardable
    include Query

    attr_reader :config

    # --- Logger methods ---

    # Module-level logger used by all components unless overridden per-query.
    #
    # Defaults to {NullLogger} for zero overhead. Set to any +Logger+-compatible
    # instance to enable logging.
    #
    # @return [Logger]
    #
    # @example
    #   ClaudeAgent.logger = Logger.new($stderr, level: :info)
    #
    def logger
      @logger ||= default_logger
    end

    # Set the module-level logger.
    #
    # @param logger [Logger] A Logger-compatible instance
    # @return [Logger]
    def logger=(logger)
      @logger = logger
    end

    # Enable debug-level logging to stderr (or a custom output).
    #
    # Convenience method for quick debugging. Creates a +Logger+ with
    # a compact formatter and DEBUG level.
    #
    # @param output [IO] Output destination (default: +$stderr+)
    # @return [Logger] The configured logger
    #
    # @example
    #   ClaudeAgent.debug!
    #   ClaudeAgent.debug!(output: $stdout)
    #   ClaudeAgent.debug!(output: File.open("debug.log", "a"))
    #
    def debug!(output: $stderr)
      require "logger"
      self.logger = Logger.new(output, level: Logger::DEBUG).tap do |l|
        l.formatter = LOG_FORMATTER
      end
    end

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
    # @param dir [String, nil] Directory to scope sessions to
    # @param limit [Integer, nil] Maximum number of sessions to return
    # @param include_worktrees [Boolean] Include git worktree sessions
    # @return [Array<SessionInfo>]
    def list_sessions(dir: nil, limit: nil, offset: nil, include_worktrees: true)
      ListSessions.call(dir: dir, limit: limit, offset: offset, include_worktrees: include_worktrees)
    end

    # Read messages from a past session's transcript
    #
    # @param session_id [String] UUID of the session to read
    # @param dir [String, nil] Project directory
    # @param limit [Integer, nil] Maximum number of messages
    # @param offset [Integer, nil] Number of messages to skip
    # @return [Array<SessionMessage>]
    def get_session_messages(session_id, dir: nil, limit: nil, offset: nil)
      GetSessionMessages.call(session_id, dir: dir, limit: limit, offset: offset)
    end

    # Rename a session
    #
    # @param session_id [String] UUID of the session
    # @param title [String] New title
    # @param dir [String, nil] Project directory
    # @return [void]
    def rename_session(session_id, title, dir: nil)
      SessionMutations.rename_session(session_id, title, dir: dir)
    end

    # Tag a session
    #
    # @param session_id [String] UUID of the session
    # @param tag [String, nil] Tag value
    # @param dir [String, nil] Project directory
    # @return [void]
    def tag_session(session_id, tag, dir: nil)
      SessionMutations.tag_session(session_id, tag, dir: dir)
    end

    # Look up a single session by ID.
    #
    # @param session_id [String] UUID
    # @param dir [String, nil] Project directory
    # @return [SessionInfo, nil]
    def get_session_info(session_id, dir: nil)
      GetSessionInfo.call(session_id, dir: dir)
    end

    # Fork a session
    #
    # @param session_id [String] UUID of the source session
    # @param up_to_message_id [String, nil] Truncate at this message UUID
    # @param title [String, nil] Title for the forked session
    # @param dir [String, nil] Project directory
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

    # --- V2 Session API (unstable) ---

    # V2 API - UNSTABLE
    # Create a persistent session for multi-turn conversations.
    #
    # @param options [Hash, SessionOptions] Session configuration
    # @return [V2Session]
    # @alpha
    def unstable_v2_create_session(options)
      V2Session.new(options)
    end

    # V2 API - UNSTABLE
    # Resume an existing session by ID.
    #
    # @param session_id [String] The session ID to resume
    # @param options [Hash, SessionOptions] Session configuration
    # @return [V2Session]
    # @alpha
    def unstable_v2_resume_session(session_id, options)
      session = V2Session.new(options)
      session.instance_variable_set(:@resume_session_id, session_id)

      session.define_singleton_method(:build_client_options) do
        Options.new(
          model: @options.model,
          cli_path: @options.path_to_claude_code_executable,
          env: @options.env,
          allowed_tools: @options.allowed_tools,
          disallowed_tools: @options.disallowed_tools,
          can_use_tool: @options.can_use_tool,
          hooks: @options.hooks,
          permission_mode: @options.permission_mode,
          resume: @resume_session_id
        )
      end

      session
    end

    # V2 API - UNSTABLE
    # One-shot convenience function for single prompts.
    #
    # @param message [String] The prompt message
    # @param options [Hash, SessionOptions] Session configuration
    # @return [ResultMessage]
    # @alpha
    def unstable_v2_prompt(message, options)
      session = unstable_v2_create_session(options)
      begin
        session.send(message)
        result = nil
        session.stream.each do |msg|
          result = msg if msg.is_a?(ResultMessage)
        end
        result
      ensure
        session.close
      end
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

    def default_logger
      require "logger"
      if ENV["CLAUDE_AGENT_DEBUG"]
        Logger.new($stderr, level: Logger::DEBUG).tap do |l|
          l.formatter = LOG_FORMATTER
        end
      else
        NullLogger.new
      end
    end
  end
end
