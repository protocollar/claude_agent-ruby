# frozen_string_literal: true

module ClaudeAgent
  # Chainable, lazy query object for session transcript messages.
  #
  # Wraps GetSessionMessages with an Enumerable interface and
  # Rails-style `where` chaining for pagination.
  #
  # @example Basic usage
  #   relation = SessionMessageRelation.new("abc-123")
  #   relation.each { |m| puts m.type }
  #
  # @example Chaining
  #   relation.where(limit: 10).map(&:uuid)
  #   relation.where(offset: 5, limit: 10).to_a
  #
  class SessionMessageRelation
    include Enumerable

    def initialize(session_id, dir: nil, limit: nil, offset: nil)
      @session_id = session_id
      @dir = dir
      @limit = limit
      @offset = offset
    end

    # Return a new relation with updated pagination parameters.
    #
    # @param limit [Integer, nil] Maximum number of messages
    # @param offset [Integer, nil] Number of messages to skip
    # @return [SessionMessageRelation]
    def where(limit: @limit, offset: @offset)
      self.class.new(@session_id, dir: @dir, limit: limit, offset: offset)
    end

    # Iterate over messages. Required by Enumerable.
    #
    # @yield [SessionMessage] Each message in the result set
    # @return [Enumerator] if no block given
    def each(&block)
      results.each(&block)
    end

    # Materialize the relation into an array.
    #
    # @return [Array<SessionMessage>]
    def to_a
      results.dup
    end

    private

    def results
      @results ||= GetSessionMessages.call(
        @session_id, dir: @dir, limit: @limit, offset: @offset
      )
    end
  end
end
