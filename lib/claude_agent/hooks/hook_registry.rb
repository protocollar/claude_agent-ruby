# frozen_string_literal: true

module ClaudeAgent
  # Declarative hook registry with Ruby-friendly method names.
  #
  # Real methods are generated from {KNOWN_EVENTS} via naming convention:
  #   PreToolUse   → before_tool_use
  #   PostCompact  → after_compact
  #   SessionStart → on_session_start
  #
  # For events the gem doesn't know about yet, call {.register}:
  #   ClaudeAgent::HookRegistry.register("SomeFutureEvent")
  #   # Now: registry.on_some_future_event { |input, ctx| ... }
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
    include Enumerable

    # Prefix mapping for CLI ↔ Ruby name conversion.
    PREFIXES = {
      "before_" => "Pre",
      "after_" => "Post",
      "on_" => ""
    }.freeze

    # Register a CLI hook event, generating a Hook subclass and DSL method.
    #
    # @param cli_event [String] CLI event name (e.g., "PreToolUse", "SessionStart")
    # @return [Symbol] The generated Ruby method name
    #
    # @example Register an event the gem doesn't know about yet
    #   ClaudeAgent::HookRegistry.register("SomeFutureEvent")
    #   # Generates: ClaudeAgent::SomeFutureEventHook (class)
    #   # Generates: registry.on_some_future_event(matcher, timeout:) { |input, ctx| ... }
    #
    def self.register(cli_event)
      # Generate Hook subclass (e.g., ClaudeAgent::PreToolUseHook)
      # event_name is derived from the class name by convention.
      hook_class_name = "#{cli_event}Hook"
      unless ClaudeAgent.const_defined?(hook_class_name)
        ClaudeAgent.const_set(hook_class_name, Class.new(Hook))
      end

      # Generate DSL method (e.g., before_tool_use)
      method_name = cli_to_ruby_method(cli_event)
      define_method(method_name) do |matcher = nil, timeout: nil, &callback|
        add_matcher(cli_event, matcher, timeout: timeout, &callback)
      end
      method_name
    end

    # Convert a CLI event name to a Ruby method name.
    # @example "PreToolUse" → :before_tool_use
    def self.cli_to_ruby_method(cli_event)
      prefix, replacement = PREFIXES.detect { |_, v| cli_event.start_with?(v) && !v.empty? }
      if prefix
        remainder = cli_event.delete_prefix(replacement)
        :"#{prefix}#{remainder.underscore}"
      else
        :"on_#{cli_event.underscore}"
      end
    end

    # Normalize any hooks input into a HookRegistry.
    # @param input [HookRegistry, Hash, nil]
    # @return [HookRegistry, nil]
    def self.wrap(input)
      case input
      when HookRegistry then input
      when Hash then from_hash(input)
      end
    end

    # Build a HookRegistry from a raw hooks hash.
    # @param hash [Hash{String => Array<Hook>}]
    # @return [HookRegistry]
    def self.from_hash(hash)
      registry = new
      hash.each do |event, hooks|
        Array(hooks).each { |hook| registry[event] << hook }
      end
      registry
    end

    # CLI event names that ship with the gem.
    KNOWN_EVENTS = %w[
      PreToolUse
      PostToolUse
      PostToolUseFailure
      Notification
      UserPromptSubmit
      SessionStart
      SessionEnd
      Stop
      StopFailure
      SubagentStart
      SubagentStop
      PreCompact
      PostCompact
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

    KNOWN_EVENTS.each { |event| register(event) }

    # @param block [Proc] DSL block yielding self
    def initialize(&block)
      @matchers = Hash.new { |h, k| h[k] = [] }
      yield self if block_given?
    end

    # Iterate over registered events and their hooks.
    # @yield [event, hooks] CLI event name and its array of Hook instances
    def each(&block)
      @matchers.each(&block)
    end

    # Access hooks for a specific event.
    # @param event [String] CLI event name
    # @return [Array<Hook>]
    def [](event)
      @matchers[event]
    end

    # Check if hooks are registered for a specific event.
    # @param event [String] CLI event name
    # @return [Boolean]
    def key?(event)
      @matchers.key?(event)
    end

    # Merge another HookRegistry additively (concatenates matchers per event).
    #
    # @param other [HookRegistry] Registry to merge
    # @return [HookRegistry] New registry with combined matchers
    def merge(other)
      merged = self.class.new
      @matchers.each { |event, hooks| hooks.each { |h| merged.matchers[event] << h } }
      other.matchers.each { |event, hooks| hooks.each { |h| merged.matchers[event] << h } }
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

    protected

    # @return [Hash{String => Array<Hook>}]
    def matchers
      @matchers
    end

    private

    def add_matcher(cli_event, matcher, timeout: nil, &callback)
      hook_class = ClaudeAgent.const_get("#{cli_event}Hook")
      @matchers[cli_event] << hook_class.new(
        matcher: normalize_matcher(matcher),
        callbacks: [ callback ],
        timeout: timeout
      )
      self
    end

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
