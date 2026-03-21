# frozen_string_literal: true

module ClaudeAgent
  # Base hook type. Subclasses are generated per event by {HookRegistry.register}.
  #
  # @example
  #   hook = ClaudeAgent::PreToolUseHook.new(
  #     matcher: "Bash|Write",
  #     callbacks: [->(input, context) { {continue_: true} }],
  #     timeout: 30
  #   )
  #   hook.event_name  #=> "PreToolUse"
  #
  class Hook < ImmutableRecord
    # Pairs a Hook with one of its callbacks in the callback registry.
    class CallbackEntry < ImmutableRecord
      attribute :hook
      attribute :callback
    end

    attribute :matcher
    attribute :callbacks
    attribute :timeout, default: nil

    # CLI event name derived from class name by convention.
    # @example PreToolUseHook → "PreToolUse"
    # @return [String, nil] nil for base Hook class
    def event_name
      self.class.event_name
    end

    # @return [String, nil]
    def self.event_name
      name&.demodulize&.delete_suffix("Hook").presence
    end

    # Build the CLI config entry for this hook, registering callbacks in the registry.
    #
    # @param index [Integer] Hook index within the event
    # @param registry [Hash] Callback registry to populate (callback_id → CallbackEntry)
    # @return [Hash] CLI-ready config entry
    def to_config(index, registry)
      callback_ids = callbacks.each_with_index.map do |callback, cidx|
        callback_id = "hook_#{event_name}_#{index}_#{cidx}"
        registry[callback_id] = CallbackEntry.new(hook: self, callback: callback)
        callback_id
      end

      entry = { matcher: matcher, hookCallbackIds: callback_ids }
      entry[:timeout] = timeout if timeout
      entry
    end

    # Dispatch a callback with structured input and context.
    #
    # @param callback [Proc] The callback to invoke
    # @param raw_input [Hash] Raw input hash from the CLI
    # @param tool_use_id [String, nil] Tool use ID from the request
    # @return [Hash] Callback result
    def dispatch(callback, raw_input, tool_use_id: nil)
      input = HookInput.new(hook_event_name: event_name, **raw_input)
      context = HookContext.new(tool_use_id: tool_use_id)
      callback.call(input, context)
    end

    # Check if this hook matches a tool name
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
end
