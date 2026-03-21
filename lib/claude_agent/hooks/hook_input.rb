# frozen_string_literal: true

module ClaudeAgent
  # Dynamic hook input that wraps whatever the CLI sends.
  #
  # Base fields (session_id, cwd, etc.) are first-class readers.
  # Event-specific fields (tool_name, trigger, etc.) are accessed
  # dynamically via method_missing — no per-event subclass needed.
  #
  # @example
  #   input = HookInput.new(hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: "ls"})
  #   input.hook_event_name  #=> "PreToolUse"
  #   input.tool_name        #=> "Bash"
  #   input[:tool_input]     #=> {command: "ls"}
  #   input.to_h             #=> {hook_event_name: "PreToolUse", tool_name: "Bash", ...}
  #
  class HookInput
    BASE_FIELDS = %i[hook_event_name session_id transcript_path cwd permission_mode agent_id agent_type].freeze

    attr_reader(*BASE_FIELDS)

    # Extra event-specific fields as a frozen hash
    attr_reader :fields

    def initialize(hook_event_name: nil, session_id: nil, transcript_path: nil, cwd: nil, permission_mode: nil, agent_id: nil, agent_type: nil, **extra)
      @hook_event_name = hook_event_name
      @session_id = session_id
      @transcript_path = transcript_path
      @cwd = cwd
      @permission_mode = permission_mode
      @agent_id = agent_id
      @agent_type = agent_type
      @fields = extra.freeze
      freeze
    end

    # Hash-style access for any field (base or extra)
    # @param key [Symbol, String] Field name
    # @return [Object, nil]
    def [](key)
      key = key.to_sym
      if BASE_FIELDS.include?(key)
        public_send(key)
      else
        @fields[key]
      end
    end

    # @return [Hash] All fields merged into a single hash
    def to_h
      BASE_FIELDS.each_with_object({}) do |field, hash|
        value = public_send(field)
        hash[field] = value unless value.nil?
      end.merge(@fields)
    end

    private

    def respond_to_missing?(name, include_private = false)
      @fields.key?(name) || super
    end

    def method_missing(name, *args)
      if @fields.key?(name)
        @fields[name]
      else
        super
      end
    end
  end
end
