# frozen_string_literal: true

module ClaudeAgent
  # Hook events that can be intercepted (TypeScript SDK parity)
  HOOK_EVENTS = %w[
    PreToolUse
    PostToolUse
    PostToolUseFailure
    Notification
    UserPromptSubmit
    SessionStart
    SessionEnd
    Stop
    SubagentStart
    SubagentStop
    PreCompact
    PermissionRequest
    Setup
    TeammateIdle
    TaskCompleted
    Elicitation
    ElicitationResult
    ConfigChange
    WorktreeCreate
    WorktreeRemove
    InstructionsLoaded
  ].freeze

  # Matcher configuration for hooks
  #
  # @example Basic usage
  #   matcher = HookMatcher.new(
  #     matcher: "Bash|Write",
  #     callbacks: [->(input, context) { {continue_: true} }],
  #     timeout: 30
  #   )
  #
  HookMatcher = Data.define(:matcher, :callbacks, :timeout) do
    def initialize(matcher:, callbacks:, timeout: nil)
      super
    end

    # Check if this matcher matches a tool name
    # @param tool_name [String] Tool name to check
    # @return [Boolean]
    def matches?(tool_name)
      case matcher
      when String
        if matcher.include?("|")
          matcher.split("|").any? { |m| tool_name == m }
        else
          Regexp.new(matcher).match?(tool_name)
        end
      when Regexp
        matcher.match?(tool_name)
      else
        true
      end
    end
  end

  # Context passed to hook callbacks
  #
  HookContext = Data.define(:tool_use_id) do
    def initialize(tool_use_id: nil)
      super
    end
  end

  # Base class for hook input types (TypeScript SDK parity)
  #
  # Subclasses are generated declaratively via {.define_input}, which creates
  # a class with attr_readers, a keyword-argument initializer, and automatic
  # hook_event_name/base field inheritance.
  #
  class BaseHookInput
    attr_reader :hook_event_name, :session_id, :transcript_path, :cwd, :permission_mode, :agent_id, :agent_type

    def initialize(hook_event_name:, session_id: nil, transcript_path: nil, cwd: nil, permission_mode: nil, agent_id: nil, agent_type: nil, **kwargs)
      @hook_event_name = hook_event_name
      @session_id = session_id
      @transcript_path = transcript_path
      @cwd = cwd
      @permission_mode = permission_mode
      @agent_id = agent_id
      @agent_type = agent_type
    end

    # Define a hook input subclass declaratively
    #
    # Generates a complete input class with attr_readers, a keyword-argument
    # initializer, and automatic hook_event_name forwarding. The generated class
    # is registered as ClaudeAgent::{event_name}Input.
    #
    # @param event_name [String] Hook event name (e.g., "PreToolUse")
    # @param required [Array<Symbol>] Required keyword arguments
    # @param optional [Hash<Symbol, Object>] Optional keyword arguments with defaults
    # @param constants [Hash<Symbol, Object>] Constants to define on the class
    # @param block [Proc] Optional block for additional instance methods
    # @return [Class] The generated subclass
    #
    # @example Simple declaration
    #   BaseHookInput.define_input "PreToolUse",
    #     required: [:tool_name, :tool_input],
    #     optional: { tool_use_id: nil }
    #
    # @example With custom behavior
    #   BaseHookInput.define_input "Setup",
    #     required: [:trigger] do
    #       def init? = trigger == "init"
    #       def maintenance? = trigger == "maintenance"
    #     end
    #
    def self.define_input(event_name, required: [], optional: {}, constants: {}, &block)
      klass = Class.new(self)
      all_fields = required + optional.keys
      klass.attr_reader(*all_fields)

      # Build keyword argument signature
      params = required.map { |f| "#{f}:" }
      params += optional.map { |f, default| "#{f}: #{default.inspect}" }
      params << "**kwargs"

      # Build instance variable assignments
      assignments = all_fields.map { |f| "@#{f} = #{f}" }.join("\n      ")

      klass.class_eval(<<~RUBY, __FILE__, __LINE__ + 1)
        def initialize(#{params.join(", ")})
          super(hook_event_name: "#{event_name}", **kwargs)
          #{assignments}
        end
      RUBY

      constants.each { |name, value| klass.const_set(name, value) }
      klass.class_eval(&block) if block

      ClaudeAgent.const_set("#{event_name}Input", klass)
    end
  end

  # --- Hook Input Declarations ---
  #
  # Each declaration generates a complete input class with:
  # - attr_readers for all fields
  # - initialize with required/optional keyword arguments
  # - Automatic hook_event_name and base field inheritance

  BaseHookInput.define_input "PreToolUse",
    required: [ :tool_name, :tool_input ],
    optional: { tool_use_id: nil }

  BaseHookInput.define_input "PostToolUse",
    required: [ :tool_name, :tool_input, :tool_response ],
    optional: { tool_use_id: nil }

  BaseHookInput.define_input "PostToolUseFailure",
    required: [ :tool_name, :tool_input, :error ],
    optional: { tool_use_id: nil, is_interrupt: nil }

  BaseHookInput.define_input "Notification",
    required: [ :message ],
    optional: { title: nil, notification_type: nil }

  BaseHookInput.define_input "UserPromptSubmit",
    required: [ :prompt ]

  BaseHookInput.define_input "SessionStart",
    required: [ :source ],
    optional: { agent_type: nil, model: nil }

  BaseHookInput.define_input "SessionEnd",
    required: [ :reason ]

  BaseHookInput.define_input "Stop",
    optional: { stop_hook_active: false, last_assistant_message: nil }

  BaseHookInput.define_input "SubagentStart",
    required: [ :agent_id, :agent_type ]

  BaseHookInput.define_input "SubagentStop",
    optional: { stop_hook_active: false, agent_id: nil, agent_transcript_path: nil, agent_type: nil, last_assistant_message: nil }

  BaseHookInput.define_input "PreCompact",
    required: [ :trigger ],
    optional: { custom_instructions: nil }

  BaseHookInput.define_input "PermissionRequest",
    required: [ :tool_name, :tool_input ],
    optional: { permission_suggestions: nil }

  BaseHookInput.define_input "Setup",
    required: [ :trigger ] do
      def init? = trigger == "init"
      def maintenance? = trigger == "maintenance"
    end

  BaseHookInput.define_input "TeammateIdle",
    required: [ :teammate_name, :team_name ]

  BaseHookInput.define_input "TaskCompleted",
    required: [ :task_id, :task_subject ],
    optional: { task_description: nil, teammate_name: nil, team_name: nil }

  BaseHookInput.define_input "Elicitation",
    required: [ :mcp_server_name, :message ],
    optional: { mode: nil, url: nil, elicitation_id: nil, requested_schema: nil }

  BaseHookInput.define_input "ElicitationResult",
    required: [ :mcp_server_name, :action ],
    optional: { elicitation_id: nil, mode: nil, content: nil }

  BaseHookInput.define_input "ConfigChange",
    required: [ :source ],
    optional: { file_path: nil },
    constants: { SOURCES: %w[user_settings project_settings local_settings policy_settings skills].freeze }

  BaseHookInput.define_input "WorktreeCreate",
    required: [ :name ]

  BaseHookInput.define_input "WorktreeRemove",
    required: [ :worktree_path ]

  BaseHookInput.define_input "InstructionsLoaded",
    required: [ :file_path, :memory_type, :load_reason ],
    optional: { globs: nil, trigger_file_path: nil, parent_file_path: nil },
    constants: {
      MEMORY_TYPES: %w[User Project Local Managed].freeze,
      LOAD_REASONS: %w[session_start nested_traversal path_glob_match include].freeze
    }
end
