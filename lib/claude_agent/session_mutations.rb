# frozen_string_literal: true

require "json"

module ClaudeAgent
  # Session mutation operations: rename and tag sessions.
  #
  # Appends JSONL entries to session files to modify session metadata.
  # Follows the TypeScript SDK pattern of file-level mutations.
  #
  # @example Rename a session
  #   ClaudeAgent.rename_session("abc-123-...", "My new title")
  #
  # @example Tag a session
  #   ClaudeAgent.tag_session("abc-123-...", "important")
  #
  # @example Clear a tag
  #   ClaudeAgent.tag_session("abc-123-...", nil)
  #
  module SessionMutations
    # Unicode characters to strip from tag values (zero-width chars, directional marks)
    UNICODE_SANITIZE_PATTERN = /[\u200B\u200C\u200D\uFEFF\u200E\u200F\u202A-\u202E\u2066-\u2069]/

    module_function

    # Rename a session by appending a custom-title entry to its session file.
    #
    # @param session_id [String] UUID of the session to rename
    # @param title [String] New title for the session (must be non-empty)
    # @param dir [String, nil] Project directory to find the session in.
    #   When nil, searches all projects.
    # @return [void]
    # @raise [ArgumentError] If session_id is not a valid UUID or title is empty
    # @raise [Error] If the session file is not found
    def rename_session(session_id, title, dir: nil)
      validate_session_id!(session_id)
      raise ArgumentError, "title must be a non-empty string" if title.nil? || title.to_s.strip.empty?

      path = find_session_file(session_id, dir: dir)
      raise Error, "Session not found: #{session_id}" unless path

      entry = {
        type: "custom-title",
        customTitle: title.to_s,
        sessionId: session_id
      }

      append_jsonl(path, entry)
    end

    # Tag a session by appending a tag entry to its session file.
    #
    # @param session_id [String] UUID of the session to tag
    # @param tag [String, nil] Tag value. Pass nil to clear the tag.
    # @param dir [String, nil] Project directory to find the session in.
    #   When nil, searches all projects.
    # @return [void]
    # @raise [ArgumentError] If session_id is not a valid UUID
    # @raise [Error] If the session file is not found
    def tag_session(session_id, tag, dir: nil)
      validate_session_id!(session_id)

      path = find_session_file(session_id, dir: dir)
      raise Error, "Session not found: #{session_id}" unless path

      sanitized_tag = tag.nil? ? "" : sanitize_unicode(tag.to_s)

      entry = {
        type: "tag",
        tag: sanitized_tag,
        sessionId: session_id
      }

      append_jsonl(path, entry)
    end

    # --- Private Helpers ---

    # Validate that a string is a valid UUID.
    # @param session_id [String]
    # @raise [ArgumentError] If not a valid UUID
    def validate_session_id!(session_id)
      unless SessionPaths::UUID_PATTERN.match?(session_id.to_s)
        raise ArgumentError, "Invalid session_id: #{session_id}. Must be a valid UUID."
      end
    end

    # Find a session file by UUID, searching project directories.
    # @param session_id [String] UUID
    # @param dir [String, nil] Optional directory to scope the search
    # @return [String, nil] Path to the .jsonl file or nil
    def find_session_file(session_id, dir: nil)
      filename = "#{session_id}.jsonl"

      if dir
        resolved = SessionPaths.realpath(dir)
        project_dir = SessionPaths.find_project_dir(resolved)
        return nil unless project_dir

        path = File.join(project_dir, filename)
        return path if File.exist?(path)

        # Check worktrees
        worktrees = SessionPaths.git_worktrees(resolved)
        worktrees.each do |wt|
          wt_project_dir = SessionPaths.find_project_dir(wt)
          next unless wt_project_dir

          wt_path = File.join(wt_project_dir, filename)
          return wt_path if File.exist?(wt_path)
        end

        nil
      else
        # Search all project directories
        base = SessionPaths.projects_dir
        return nil unless File.directory?(base)

        Dir.entries(base).each do |entry|
          next if entry.start_with?(".")
          dir_path = File.join(base, entry)
          next unless File.directory?(dir_path)

          path = File.join(dir_path, filename)
          return path if File.exist?(path)
        end

        nil
      end
    end

    # Sanitize a string by removing zero-width and directional Unicode characters.
    # @param str [String]
    # @return [String]
    def sanitize_unicode(str)
      str.gsub(UNICODE_SANITIZE_PATTERN, "")
    end

    # Atomically append a JSONL entry to a file.
    # @param path [String] File path
    # @param entry [Hash] JSON-serializable entry
    def append_jsonl(path, entry)
      File.open(path, "a") do |f|
        f.write("#{JSON.generate(entry)}\n")
      end
    end
  end
end
