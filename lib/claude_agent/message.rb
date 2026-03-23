# frozen_string_literal: true

module ClaudeAgent
  # Shared interface for all message and content block types.
  #
  # Provides a consistent API across the 22+ message types and 8 content
  # block types. Included (not prepended) into all ImmutableRecord subclasses
  # that represent messages or content blocks.
  #
  # @example Universal text extraction
  #   message.text_content  # works on AssistantMessage, UserMessage, TextBlock, etc.
  #
  # @example Duck-type checks
  #   message.session_message?   # has uuid + session_id?
  #   message.identifiable?      # has uuid?
  #
  # @example Pattern matching
  #   case message
  #   in { type: :assistant }
  #     puts message.text_content
  #   in { type: :result }
  #     puts message.cost
  #   end
  #
  module Message
    # Universal text extraction across all message and content block types.
    #
    # @return [String] Extracted text (empty string if no text available)
    def text_content
      case self
      when AssistantMessage
        text
      when UserMessage, UserMessageReplay
        content.is_a?(String) ? content : ""
      when TextBlock
        text
      when ThinkingBlock
        thinking
      when StreamEvent
        delta_text || ""
      when ToolProgressMessage
        ""
      when ResultMessage
        ""
      when GenericMessage
        raw.is_a?(Hash) ? (raw[:text] || raw["text"] || "").to_s : ""
      else
        respond_to?(:text) ? (text || "").to_s : ""
      end
    end

    # Whether this message carries session identity (uuid + session_id).
    #
    # @return [Boolean]
    def session_message?
      respond_to?(:uuid) && respond_to?(:session_id) &&
        !uuid.nil? && !session_id.nil?
    end

    # Whether this message has a UUID.
    #
    # @return [Boolean]
    def identifiable?
      respond_to?(:uuid) && !uuid.nil?
    end

    # Override deconstruct_keys to include :type for pattern matching.
    #
    # Allows `case msg; in { type: :assistant }` to work naturally.
    # The virtual :type key is added to ImmutableRecord's attribute hash.
    #
    # @param keys [Array<Symbol>, nil]
    # @return [Hash]
    def deconstruct_keys(keys)
      if keys.nil?
        { type: type }.merge(super)
      elsif keys.include?(:type)
        member_keys = keys - [ :type ]
        base = member_keys.empty? ? {} : super(member_keys)
        { type: type }.merge(base)
      else
        super
      end
    end
  end
end
