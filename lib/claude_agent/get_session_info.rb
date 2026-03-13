# frozen_string_literal: true

module ClaudeAgent
  # Looks up a single session by ID and returns its metadata.
  #
  # Reuses ListSessions parsing logic to read session files from disk.
  # Searches project directories for the session file by UUID.
  #
  # @example
  #   info = ClaudeAgent.get_session_info("abc-123-...")
  #   puts info.summary if info
  #
  module GetSessionInfo
    module_function

    # Look up a single session by ID.
    #
    # @param session_id [String] UUID of the session to look up
    # @param dir [String, nil] Project directory to scope the search.
    #   When nil, searches all projects.
    # @return [SessionInfo, nil] Session metadata or nil if not found
    def call(session_id, dir: nil)
      unless SessionPaths::UUID_PATTERN.match?(session_id.to_s)
        raise ArgumentError, "Invalid session_id: #{session_id}. Must be a valid UUID."
      end

      filename = "#{session_id}.jsonl"

      if dir
        find_in_directory(session_id, filename, dir)
      else
        find_in_all_projects(session_id, filename)
      end
    end

    # --- Private Helpers ---

    def find_in_directory(session_id, filename, dir)
      resolved = SessionPaths.realpath(dir)
      project_dir = SessionPaths.find_project_dir(resolved)

      if project_dir
        result = try_parse(project_dir, filename, session_id)
        return result if result
      end

      # Check worktrees
      worktrees = SessionPaths.git_worktrees(resolved)
      worktrees.each do |wt|
        wt_project_dir = SessionPaths.find_project_dir(wt)
        next unless wt_project_dir

        result = try_parse(wt_project_dir, filename, session_id)
        return result if result
      end

      nil
    end
    private_class_method :find_in_directory

    def find_in_all_projects(session_id, filename)
      base = SessionPaths.projects_dir
      return nil unless File.directory?(base)

      Dir.entries(base).each do |entry|
        next if entry.start_with?(".")
        dir_path = File.join(base, entry)
        next unless File.directory?(dir_path)

        result = try_parse(dir_path, filename, session_id)
        return result if result
      end

      nil
    end
    private_class_method :find_in_all_projects

    def try_parse(project_dir, filename, session_id)
      path = File.join(project_dir, filename)
      return nil unless File.exist?(path)

      ListSessions.send(:parse_session_file, path, session_id)
    end
    private_class_method :try_parse
  end
end
