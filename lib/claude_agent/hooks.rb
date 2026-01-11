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
  class BaseHookInput
    attr_reader :hook_event_name, :session_id, :transcript_path, :cwd, :permission_mode

    def initialize(hook_event_name:, session_id: nil, transcript_path: nil, cwd: nil, permission_mode: nil, **kwargs)
      @hook_event_name = hook_event_name
      @session_id = session_id
      @transcript_path = transcript_path
      @cwd = cwd
      @permission_mode = permission_mode
    end
  end

  # Input for PreToolUse hook
  #
  class PreToolUseInput < BaseHookInput
    attr_reader :tool_name, :tool_input, :tool_use_id

    def initialize(tool_name:, tool_input:, tool_use_id: nil, **kwargs)
      super(hook_event_name: "PreToolUse", **kwargs)
      @tool_name = tool_name
      @tool_input = tool_input
      @tool_use_id = tool_use_id
    end
  end

  # Input for PostToolUse hook
  #
  class PostToolUseInput < BaseHookInput
    attr_reader :tool_name, :tool_input, :tool_response, :tool_use_id

    def initialize(tool_name:, tool_input:, tool_response:, tool_use_id: nil, **kwargs)
      super(hook_event_name: "PostToolUse", **kwargs)
      @tool_name = tool_name
      @tool_input = tool_input
      @tool_response = tool_response
      @tool_use_id = tool_use_id
    end
  end

  # Input for PostToolUseFailure hook (TypeScript SDK parity)
  #
  class PostToolUseFailureInput < BaseHookInput
    attr_reader :tool_name, :tool_input, :tool_use_id, :error, :is_interrupt

    def initialize(tool_name:, tool_input:, error:, tool_use_id: nil, is_interrupt: nil, **kwargs)
      super(hook_event_name: "PostToolUseFailure", **kwargs)
      @tool_name = tool_name
      @tool_input = tool_input
      @tool_use_id = tool_use_id
      @error = error
      @is_interrupt = is_interrupt
    end
  end

  # Input for Notification hook (TypeScript SDK parity)
  #
  class NotificationInput < BaseHookInput
    attr_reader :message, :title, :notification_type

    def initialize(message:, title: nil, notification_type: nil, **kwargs)
      super(hook_event_name: "Notification", **kwargs)
      @message = message
      @title = title
      @notification_type = notification_type
    end
  end

  # Input for UserPromptSubmit hook
  #
  class UserPromptSubmitInput < BaseHookInput
    attr_reader :prompt

    def initialize(prompt:, **kwargs)
      super(hook_event_name: "UserPromptSubmit", **kwargs)
      @prompt = prompt
    end
  end

  # Input for SessionStart hook (TypeScript SDK parity)
  #
  class SessionStartInput < BaseHookInput
    attr_reader :source, :agent_type

    # @param source [String] One of: "startup", "resume", "clear", "compact"
    # @param agent_type [String, nil] Type of agent if running in subagent context
    def initialize(source:, agent_type: nil, **kwargs)
      super(hook_event_name: "SessionStart", **kwargs)
      @source = source
      @agent_type = agent_type
    end
  end

  # Input for SessionEnd hook (TypeScript SDK parity)
  #
  class SessionEndInput < BaseHookInput
    attr_reader :reason

    def initialize(reason:, **kwargs)
      super(hook_event_name: "SessionEnd", **kwargs)
      @reason = reason
    end
  end

  # Input for Stop hook
  #
  class StopInput < BaseHookInput
    attr_reader :stop_hook_active

    def initialize(stop_hook_active: false, **kwargs)
      super(hook_event_name: "Stop", **kwargs)
      @stop_hook_active = stop_hook_active
    end
  end

  # Input for SubagentStart hook (TypeScript SDK parity)
  #
  class SubagentStartInput < BaseHookInput
    attr_reader :agent_id, :agent_type

    def initialize(agent_id:, agent_type:, **kwargs)
      super(hook_event_name: "SubagentStart", **kwargs)
      @agent_id = agent_id
      @agent_type = agent_type
    end
  end

  # Input for SubagentStop hook
  #
  class SubagentStopInput < BaseHookInput
    attr_reader :stop_hook_active, :agent_id, :agent_transcript_path

    def initialize(stop_hook_active: false, agent_id: nil, agent_transcript_path: nil, **kwargs)
      super(hook_event_name: "SubagentStop", **kwargs)
      @stop_hook_active = stop_hook_active
      @agent_id = agent_id
      @agent_transcript_path = agent_transcript_path
    end
  end

  # Input for PreCompact hook
  #
  class PreCompactInput < BaseHookInput
    attr_reader :trigger, :custom_instructions

    # @param trigger [String] One of: "manual", "auto"
    # @param custom_instructions [String, nil] Custom instructions for compaction
    def initialize(trigger:, custom_instructions: nil, **kwargs)
      super(hook_event_name: "PreCompact", **kwargs)
      @trigger = trigger
      @custom_instructions = custom_instructions
    end
  end

  # Input for PermissionRequest hook (TypeScript SDK parity)
  #
  class PermissionRequestInput < BaseHookInput
    attr_reader :tool_name, :tool_input, :permission_suggestions

    def initialize(tool_name:, tool_input:, permission_suggestions: nil, **kwargs)
      super(hook_event_name: "PermissionRequest", **kwargs)
      @tool_name = tool_name
      @tool_input = tool_input
      @permission_suggestions = permission_suggestions
    end
  end
end
