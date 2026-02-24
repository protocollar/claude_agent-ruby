# frozen_string_literal: true

module ClaudeAgent
  # Dispatches typed events as messages flow through a conversation turn.
  #
  # Register handlers for specific events instead of writing `case` statements
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
    # Events:
    #   :message      — every message (catch-all)
    #   :text         — AssistantMessage text content
    #   :thinking     — AssistantMessage thinking content
    #   :tool_use     — ToolUseBlock or ServerToolUseBlock
    #   :tool_result  — ToolResultBlock or ServerToolResultBlock, paired with original tool_use
    #   :result       — ResultMessage (end of turn)

    def initialize
      @handlers = Hash.new { |h, k| h[k] = [] }
      @pending_tool_uses = {}
    end

    # Register a handler for an event
    #
    # @param event [Symbol] Event name
    # @yield Event-specific arguments
    # @return [self]
    def on(event, &block)
      @handlers[event] << block
      self
    end

    # @!method on_message(&block)
    #   Register a handler for every message
    #   @yield [message] Any message object
    #   @return [self]

    # @!method on_text(&block)
    #   Register a handler for assistant text content
    #   @yield [String] Text from the AssistantMessage
    #   @return [self]

    # @!method on_thinking(&block)
    #   Register a handler for assistant thinking content
    #   @yield [String] Thinking from the AssistantMessage
    #   @return [self]

    # @!method on_tool_use(&block)
    #   Register a handler for tool use requests
    #   @yield [ToolUseBlock, ServerToolUseBlock] The tool use block
    #   @return [self]

    # @!method on_tool_result(&block)
    #   Register a handler for tool results, paired with the original request
    #   @yield [ToolResultBlock, ToolUseBlock|nil] Result block and matched tool use
    #   @return [self]

    # @!method on_result(&block)
    #   Register a handler for the final ResultMessage
    #   @yield [ResultMessage] The result
    #   @return [self]

    %i[message text thinking tool_use tool_result result].each do |event|
      define_method(:"on_#{event}") { |&block| on(event, &block) }
    end

    # Dispatch a message to registered handlers
    #
    # @param message [Message] Any SDK message
    # @return [void]
    def handle(message)
      emit(:message, message)

      case message
      when AssistantMessage
        handle_assistant(message)
      when UserMessage, UserMessageReplay
        handle_user(message)
      when ResultMessage
        emit(:result, message)
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
