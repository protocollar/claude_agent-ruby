# frozen_string_literal: true

module ClaudeAgent
  # Dispatches typed events as messages flow through a conversation turn.
  #
  # Three event layers fire for every message:
  #
  # 1. **Catch-all** — +:message+ fires for every message
  # 2. **Type-based** — +message.type+ fires (e.g. +:assistant+, +:stream_event+, +:status+)
  # 3. **Decomposed** — convenience events for rich content types (+:text+, +:thinking+, etc.)
  #
  # Register handlers for specific events instead of writing +case+ statements
  # over raw message types. Use standalone or via {Client#on}.
  #
  # @example Standalone
  #   handler = ClaudeAgent::EventHandler.new
  #   handler.on_text { |text| print text }
  #   handler.on_tool_use { |tool| puts "Using: #{tool.display_label}" }
  #   handler.on_result { |result| puts "Cost: $#{result.total_cost_usd}" }
  #
  #   client.receive_response.each { |msg| handler.handle(msg) }
  #
  # @example Type-based events
  #   handler.on_stream_event { |evt| handle_stream(evt) }
  #   handler.on_tool_progress { |prog| update_spinner(prog) }
  #   handler.on_status { |status| show_status(status) }
  #
  # @example Via Client
  #   client.on_text { |text| print text }
  #   client.on_tool_use { |tool| puts tool.display_label }
  #   turn = client.send_and_receive("Fix the bug")
  #
  # @example Chaining
  #   handler = ClaudeAgent::EventHandler.new
  #     .on_text { |text| print text }
  #     .on_result { |r| puts "\nDone!" }
  #
  class EventHandler
    # Type-based events — one per message type, auto-dispatched from message.type
    TYPE_EVENTS = %i[
      user assistant system result stream_event compact_boundary
      status tool_progress hook_response auth_status task_notification
      hook_started hook_progress tool_use_summary task_started
      task_progress rate_limit_event prompt_suggestion files_persisted
      elicitation_complete local_command_output
    ].freeze

    # Decomposed events — extracted content from rich message types
    DECOMPOSED_EVENTS = %i[text thinking tool_use tool_result].freeze

    # Meta events — catch-all
    META_EVENTS = %i[message].freeze

    # All known events
    EVENTS = (META_EVENTS + TYPE_EVENTS + DECOMPOSED_EVENTS).freeze

    # Create an EventHandler with block-based DSL.
    #
    # @example
    #   handler = ClaudeAgent::EventHandler.define do
    #     on_text { |t| print t }
    #     on_result { |r| puts "\nCost: $#{r.total_cost_usd}" }
    #   end
    #
    # @yield [self] Block evaluated in the context of the new handler
    # @return [EventHandler]
    def self.define(&block)
      new.tap { |h| h.instance_eval(&block) }
    end

    def initialize
      @handlers = Hash.new { |h, k| h[k] = [] }
      @pending_tool_uses = {}
    end

    # Register a handler for an event
    #
    # @param event [Symbol] Event name (any symbol, including future/unknown types)
    # @yield Event-specific arguments
    # @return [self]
    def on(event, &block)
      @handlers[event] << block
      self
    end

    # @!method on_message(&block)
    #   Register a handler for every message (catch-all)
    #   @yield [message] Any message object
    #   @return [self]

    # @!method on_assistant(&block)
    #   Register a handler for AssistantMessage
    #   @yield [AssistantMessage] The assistant message
    #   @return [self]

    # @!method on_user(&block)
    #   Register a handler for UserMessage
    #   @yield [UserMessage] The user message
    #   @return [self]

    # @!method on_result(&block)
    #   Register a handler for ResultMessage (end of turn)
    #   @yield [ResultMessage] The result
    #   @return [self]

    # @!method on_stream_event(&block)
    #   Register a handler for StreamEvent
    #   @yield [StreamEvent] The stream event
    #   @return [self]

    # @!method on_status(&block)
    #   Register a handler for StatusMessage
    #   @yield [StatusMessage] The status message
    #   @return [self]

    # @!method on_tool_progress(&block)
    #   Register a handler for ToolProgressMessage
    #   @yield [ToolProgressMessage] The tool progress message
    #   @return [self]

    # @!method on_text(&block)
    #   Register a handler for assistant text content (decomposed)
    #   @yield [String] Text from the AssistantMessage
    #   @return [self]

    # @!method on_thinking(&block)
    #   Register a handler for assistant thinking content (decomposed)
    #   @yield [String] Thinking from the AssistantMessage
    #   @return [self]

    # @!method on_tool_use(&block)
    #   Register a handler for tool use requests (decomposed)
    #   @yield [ToolUseBlock, ServerToolUseBlock] The tool use block
    #   @return [self]

    # @!method on_tool_result(&block)
    #   Register a handler for tool results, paired with the original request (decomposed)
    #   @yield [ToolResultBlock, ToolUseBlock|nil] Result block and matched tool use
    #   @return [self]

    EVENTS.each do |event|
      define_method(:"on_#{event}") { |&block| on(event, &block) }
    end

    # Dispatch a message to registered handlers
    #
    # Fires events in order:
    # 1. +:message+ (catch-all)
    # 2. +message.type+ (type-based, e.g. +:assistant+, +:stream_event+)
    # 3. Decomposed events (+:text+, +:thinking+, +:tool_use+, +:tool_result+)
    #
    # @param message [Message] Any SDK message
    # @return [void]
    def handle(message)
      emit(:message, message)
      emit(message.type, message)

      case message
      when AssistantMessage
        handle_assistant(message)
      when UserMessage, UserMessageReplay
        handle_user(message)
      end
    end

    # Clear turn-level tracking state (pending tool uses)
    #
    # Called automatically between turns when used via Client.
    # Call manually when reusing a standalone handler across turns.
    #
    # @return [void]
    def reset!
      @pending_tool_uses.clear
    end

    # Whether any handlers have been registered
    # @return [Boolean]
    def has_handlers?
      @handlers.any? { |_, v| v.any? }
    end

    private

    def handle_assistant(message)
      text = message.text
      emit(:text, text) unless text.empty?

      thinking = message.thinking
      emit(:thinking, thinking) unless thinking.empty?

      message.content.each do |block|
        case block
        when ToolUseBlock, ServerToolUseBlock
          @pending_tool_uses[block.id] = block
          emit(:tool_use, block)
        end
      end
    end

    def handle_user(message)
      return unless message.content.is_a?(Array)

      message.content.each do |block|
        case block
        when ToolResultBlock, ServerToolResultBlock
          tool_use = @pending_tool_uses.delete(block.tool_use_id)
          emit(:tool_result, block, tool_use)
        end
      end
    end

    def emit(event, *args)
      @handlers[event].each { |handler| handler.call(*args) }
    end
  end
end
