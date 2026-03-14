# frozen_string_literal: true

module ClaudeAgent
  # Historical session finder with Rails-like API.
  #
  # Wraps SessionInfo with a rich interface for finding sessions
  # and querying their message transcripts.
  #
  # @example Find a session by ID
  #   session = ClaudeAgent::Session.find("abc-123")
  #   session.summary  # => "Fix login bug"
  #
  # @example List all sessions
  #   sessions = ClaudeAgent::Session.all(limit: 10)
  #
  # @example Query messages with chainable relation
  #   session.messages.where(limit: 5).each { |m| puts m.type }
  #
  class Session
    attr_reader :session_id, :summary, :last_modified, :file_size,
                :custom_title, :first_prompt, :git_branch, :cwd

    def initialize(session_info)
      @session_id = session_info.session_id
      @summary = session_info.summary
      @last_modified = session_info.last_modified
      @file_size = session_info.file_size
      @custom_title = session_info.custom_title
      @first_prompt = session_info.first_prompt
      @git_branch = session_info.git_branch
      @cwd = session_info.cwd
      @dir = session_info.cwd
    end

    # Returns a chainable, Enumerable relation for this session's messages.
    #
    # @return [SessionMessageRelation]
    def messages
      SessionMessageRelation.new(session_id, dir: @dir)
    end

    class << self
      # Find a session by its UUID.
      #
      # @param session_id [String] UUID of the session
      # @param dir [String, nil] Directory to scope the search
      # @return [Session, nil] The session, or nil if not found
      def find(session_id, dir: nil)
        sessions = ListSessions.call(dir: dir)
        info = sessions.find { |s| s.session_id == session_id }
        info ? new(info) : nil
      end

      # List all sessions.
      #
      # @return [Array<Session>]
      def all
        ListSessions.call.map { |info| new(info) }
      end

      # Query sessions with optional filters.
      #
      # @param dir [String, nil] Directory to scope sessions to
      # @param limit [Integer, nil] Maximum number of sessions to return
      # @return [Array<Session>]
      def where(dir: nil, limit: nil)
        ListSessions.call(dir: dir, limit: limit).map { |info| new(info) }
      end
    end
  end
end
