# frozen_string_literal: true

module ClaudeAgent
  # Historical session finder with Rails-like API and Stripe-style resource methods.
  #
  # Wraps SessionInfo with a rich interface for finding sessions,
  # querying their message transcripts, and mutating session metadata.
  #
  # @example Find a session by ID
  #   session = ClaudeAgent::Session.find("abc-123")
  #   session.summary  # => "Fix login bug"
  #
  # @example Retrieve (raises on not found)
  #   session = ClaudeAgent::Session.retrieve("abc-123")
  #
  # @example Mutations
  #   session.rename("My Session")
  #   session.tag("important")
  #   forked = session.fork(title: "Branch off")
  #
  # @example Resume a conversation
  #   session.resume(model: "opus") { |c| c.say("Continue") }
  #
  class Session
    attr_reader :session_id, :summary, :last_modified, :file_size,
                :custom_title, :first_prompt, :git_branch, :cwd,
                :tag, :created_at

    def initialize(session_info)
      @session_id = session_info.session_id
      @summary = session_info.summary
      @last_modified = session_info.last_modified
      @file_size = session_info.file_size
      @custom_title = session_info.custom_title
      @first_prompt = session_info.first_prompt
      @git_branch = session_info.git_branch
      @cwd = session_info.cwd
      @tag = session_info.tag
      @created_at = session_info.created_at
      @dir = session_info.cwd
    end

    # Returns a chainable, Enumerable relation for this session's messages.
    #
    # @return [SessionMessageRelation]
    def messages
      SessionMessageRelation.new(session_id, dir: @dir)
    end

    # --- Instance Mutation Methods ---

    # Rename this session.
    #
    # @param title [String] New title
    # @return [self]
    def rename(title)
      SessionMutations.rename_session(session_id, title, dir: @dir)
      @custom_title = title
      self
    end

    # Tag this session.
    #
    # @param value [String, nil] Tag value. Pass nil to clear.
    # @return [self]
    def tag_session(value)
      SessionMutations.tag_session(session_id, value, dir: @dir)
      @tag = value
      self
    end

    # Fork this session.
    #
    # @param up_to [String, nil] Truncate at this message UUID (inclusive)
    # @param title [String, nil] Title for the forked session
    # @return [Session] The new forked session
    def fork(up_to: nil, title: nil)
      result = ForkSession.call(session_id, up_to_message_id: up_to, title: title, dir: @dir)
      info = GetSessionInfo.call(result.session_id, dir: @dir)
      info ? Session.new(info) : Session.new(SessionInfo.new(
        session_id: result.session_id,
        summary: title || @summary,
        last_modified: Time.now.to_i * 1000,
        file_size: 0
      ))
    end

    # Re-read session metadata from disk.
    #
    # @return [self]
    def reload
      info = GetSessionInfo.call(session_id, dir: @dir)
      raise NotFoundError, "Session not found: #{session_id}" unless info

      @summary = info.summary
      @last_modified = info.last_modified
      @file_size = info.file_size
      @custom_title = info.custom_title
      @first_prompt = info.first_prompt
      @git_branch = info.git_branch
      @cwd = info.cwd
      @tag = info.tag
      @created_at = info.created_at
      self
    end

    # Resume this session as a Conversation.
    #
    # @param kwargs Options/Conversation keyword arguments
    # @yield [Conversation] Block form with auto-cleanup
    # @return [Conversation, Object]
    def resume(**kwargs, &block)
      if block
        Conversation.open(resume: session_id, **kwargs, &block)
      else
        Conversation.resume(session_id, **kwargs)
      end
    end

    class << self
      # Find a session by its UUID (targeted lookup, not full scan).
      #
      # @param session_id [String] UUID of the session
      # @param dir [String, nil] Directory to scope the search
      # @return [Session, nil] The session, or nil if not found
      def find(session_id, dir: nil)
        info = GetSessionInfo.call(session_id, dir: dir)
        info ? new(info) : nil
      end

      # Retrieve a session by UUID. Raises if not found (Stripe convention).
      #
      # @param session_id [String] UUID of the session
      # @param dir [String, nil] Directory to scope the search
      # @return [Session]
      # @raise [NotFoundError] If session is not found
      def retrieve(session_id, dir: nil)
        info = GetSessionInfo.call(session_id, dir: dir)
        raise NotFoundError, "Session not found: #{session_id}" unless info
        new(info)
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
