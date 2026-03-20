# frozen_string_literal: true

module ClaudeAgent
  # Declarative hook registry with Ruby-friendly method names.
  #
  # Maps idiomatic Ruby method names to CLI hook event names and
  # compiles to the Hash format consumed by Options#hooks.
  #
  # @example Basic usage
  #   hooks = ClaudeAgent::HookRegistry.new do |h|
  #     h.before_tool_use(/Bash/) { |input, ctx| { continue_: true } }
  #     h.after_tool_use("Read") { |input, ctx| { continue_: true } }
  #   end
  #
  # @example Module-level convenience
  #   ClaudeAgent.hooks do |h|
  #     h.on_session_start { |input, ctx| { continue_: true } }
  #   end
  #
  class HookRegistry
    # Ruby method name → CLI event name mapping
    EVENT_MAP = {
      before_tool_use: "PreToolUse",
      after_tool_use: "PostToolUse",
      after_tool_use_failure: "PostToolUseFailure",
      on_notification: "Notification",
      on_user_prompt_submit: "UserPromptSubmit",
      on_session_start: "SessionStart",
      on_session_end: "SessionEnd",
      on_stop: "Stop",
      on_stop_failure: "StopFailure",
      on_subagent_start: "SubagentStart",
      on_subagent_stop: "SubagentStop",
      before_compact: "PreCompact",
      after_compact: "PostCompact",
      on_permission_request: "PermissionRequest",
      on_setup: "Setup",
      on_teammate_idle: "TeammateIdle",
      on_task_completed: "TaskCompleted",
      on_elicitation: "Elicitation",
      on_elicitation_result: "ElicitationResult",
      on_config_change: "ConfigChange",
      on_worktree_create: "WorktreeCreate",
      on_worktree_remove: "WorktreeRemove",
      on_instructions_loaded: "InstructionsLoaded"
    }.freeze

    # @param block [Proc] DSL block yielding self
    def initialize(&block)
      @matchers = Hash.new { |h, k| h[k] = [] }
      yield self if block_given?
    end

    # Define DSL methods for each event
    EVENT_MAP.each do |method_name, cli_event|
      define_method(method_name) do |matcher = nil, timeout: nil, &callback|
        @matchers[cli_event] << HookMatcher.new(
          matcher: normalize_matcher(matcher),
          callbacks: [ callback ],
          timeout: timeout
        )
        self
      end
    end

    # Compile to the hooks Hash format consumed by Options.
    #
    # @return [Hash{String => Array<HookMatcher>}]
    def to_hooks_hash
      @matchers.transform_values(&:dup)
    end

    # Merge another HookRegistry additively (concatenates matchers per event).
    #
    # @param other [HookRegistry] Registry to merge
    # @return [HookRegistry] New registry with combined matchers
    def merge(other)
      merged = self.class.new
      @matchers.each { |event, matchers| matchers.each { |m| merged.instance_variable_get(:@matchers)[event] << m } }
      other.instance_variable_get(:@matchers).each { |event, matchers| matchers.each { |m| merged.instance_variable_get(:@matchers)[event] << m } }
      merged
    end

    # Whether any hooks have been registered.
    # @return [Boolean]
    def empty?
      @matchers.empty?
    end

    # Number of total matchers across all events.
    # @return [Integer]
    def size
      @matchers.values.sum(&:size)
    end

    private

    def normalize_matcher(matcher)
      case matcher
      when Regexp
        matcher.source
      when String
        matcher
      when nil
        nil
      else
        matcher.to_s
      end
    end
  end
end
