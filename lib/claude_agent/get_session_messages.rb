# frozen_string_literal: true

require "json"

module ClaudeAgent
  # Reads a session's conversation transcript from its JSONL file.
  #
  # Given a session UUID, finds the session file on disk, parses all messages,
  # reconstructs the main conversation thread (handling branches and forks),
  # filters to user/assistant messages, and returns SessionMessage objects
  # with optional pagination.
  #
  # Matches the TypeScript SDK's getSessionMessages() (v0.2.59).
  #
  # @example Basic usage
  #   messages = ClaudeAgent.get_session_messages("abc-123-def")
  #   messages.each { |m| puts "#{m.type}: #{m.message}" }
  #
  # @example With pagination
  #   messages = ClaudeAgent.get_session_messages("abc-123-def", limit: 10, offset: 5)
  #
  module GetSessionMessages
    # Valid message types to include when parsing JSONL lines.
    PARSEABLE_TYPES = %w[user assistant progress system attachment].freeze

    class << self
      # Read session messages with optional pagination.
      #
      # @param session_id [String] UUID of the session to read
      # @param dir [String, nil] Project directory to find the session in
      # @param limit [Integer, nil] Maximum number of messages to return
      # @param offset [Integer, nil] Number of messages to skip from the start
      # @return [Array<SessionMessage>] User/assistant messages, or empty array if not found
      def call(session_id, dir: nil, limit: nil, offset: nil)
        return [] unless SessionPaths::UUID_PATTERN.match?(session_id)

        content = find_session_file(session_id, dir)
        return [] unless content

        raw_messages = parse_jsonl(content)
        thread = reconstruct_thread(raw_messages)
        result = thread.select { |msg| include_message?(msg) }.map { |msg| to_session_message(msg) }

        off = offset || 0
        if limit && limit > 0
          result.slice(off, limit) || []
        elsif off > 0
          result.slice(off..) || []
        else
          result
        end
      end

      private

      # Locate and read a session JSONL file from disk.
      #
      # @param session_id [String] Session UUID
      # @param dir [String, nil] Optional project directory to scope search
      # @return [String, nil] File contents or nil
      def find_session_file(session_id, dir)
        filename = "#{session_id}.jsonl"

        if dir
          resolved = SessionPaths.realpath(dir)
          project_dir = SessionPaths.find_project_dir(resolved)
          if project_dir
            content = read_session_content(project_dir, filename)
            return content if content
          end

          # Try worktrees
          worktrees = SessionPaths.git_worktrees(resolved)
          worktrees.each do |wt|
            next if wt == resolved
            wt_project_dir = SessionPaths.find_project_dir(wt)
            if wt_project_dir
              content = read_session_content(wt_project_dir, filename)
              return content if content
            end
          end

          nil
        else
          # Search all project directories
          base = SessionPaths.projects_dir
          return nil unless File.directory?(base)

          Dir.entries(base).each do |entry|
            next if entry.start_with?(".")
            entry_path = File.join(base, entry)
            next unless File.directory?(entry_path)
            content = read_session_content(entry_path, filename)
            return content if content
          end

          nil
        end
      end

      # Read a session file's full contents.
      #
      # @param dir [String] Directory containing the file
      # @param filename [String] JSONL filename
      # @return [String, nil] File contents or nil
      def read_session_content(dir, filename)
        path = File.join(dir, filename)
        File.read(path, encoding: "UTF-8")
      rescue SystemCallError
        nil
      end

      # Parse JSONL content into raw message hashes.
      # Only includes messages with valid types and a uuid field.
      #
      # @param content [String] JSONL file contents
      # @return [Array<Hash>] Parsed message hashes
      def parse_jsonl(content)
        messages = []
        content.each_line do |line|
          line = line.strip
          next if line.empty?

          begin
            parsed = JSON.parse(line)
            type = parsed["type"]
            next unless PARSEABLE_TYPES.include?(type) && parsed["uuid"].is_a?(String)
            messages << parsed
          rescue JSON::ParserError
            next
          end
        end
        messages
      end

      # Reconstruct the main conversation thread from raw messages.
      #
      # Handles branches, forks, and sidechains by:
      # 1. Building UUID -> message and UUID -> index maps
      # 2. Finding leaf messages (messages with no children)
      # 3. Walking up parentUuid chains to find user/assistant ancestors
      # 4. Picking the best leaf (highest file position, prefer main thread)
      # 5. Walking from best leaf to root to build chronological thread
      #
      # @param messages [Array<Hash>] All parsed messages from JSONL
      # @return [Array<Hash>] Chronologically ordered main thread messages
      def reconstruct_thread(messages)
        # Build UUID -> message map
        by_uuid = {}
        messages.each { |msg| by_uuid[msg["uuid"]] = msg }

        # Build UUID -> file index map (position in file)
        index_map = {}
        messages.each_with_index { |msg, i| index_map[msg["uuid"]] = i }

        # Find parent UUIDs (messages that have children pointing to them)
        parent_uuids = Set.new
        messages.each do |msg|
          parent_uuids.add(msg["parentUuid"]) if msg["parentUuid"]
        end

        # Find leaf messages (no children point to them)
        leaves = messages.reject { |msg| parent_uuids.include?(msg["uuid"]) }

        # For each leaf, walk up parentUuid chain to find nearest user/assistant ancestor
        candidates = []
        leaves.each do |leaf|
          current = leaf
          seen = Set.new
          while current
            break if seen.include?(current["uuid"])
            seen.add(current["uuid"])
            if current["type"] == "user" || current["type"] == "assistant"
              candidates << current
              break
            end
            current = current["parentUuid"] ? by_uuid[current["parentUuid"]] : nil
          end
        end

        return [] if candidates.empty?

        # Filter out sidechain/team/meta candidates
        main_candidates = candidates.reject do |msg|
          msg["isSidechain"] || msg["teamName"] || msg["isMeta"]
        end

        # Pick best: highest file position index
        pick_best = ->(arr) {
          arr.max_by { |msg| index_map[msg["uuid"]] || -1 }
        }

        best_leaf = main_candidates.empty? ? pick_best.call(candidates) : pick_best.call(main_candidates)

        # Walk from best leaf back to root, building chronological thread
        thread = []
        visited = Set.new
        current = best_leaf
        while current
          break if visited.include?(current["uuid"])
          visited.add(current["uuid"])
          thread.unshift(current) # prepend for chronological order
          current = current["parentUuid"] ? by_uuid[current["parentUuid"]] : nil
        end

        thread
      end

      # Whether a message should be included in the final output.
      #
      # @param msg [Hash] Raw message hash
      # @return [Boolean]
      def include_message?(msg)
        return false unless msg["type"] == "user" || msg["type"] == "assistant"
        return false if msg["isMeta"]
        return false if msg["isSidechain"]
        return false if msg["teamName"]
        true
      end

      # Transform a raw message hash into a SessionMessage.
      #
      # @param msg [Hash] Raw message hash from JSONL
      # @return [SessionMessage]
      def to_session_message(msg)
        SessionMessage.new(
          type: msg["type"],
          uuid: msg["uuid"],
          session_id: msg["sessionId"],
          message: msg["message"],
          parent_tool_use_id: nil
        )
      end
    end
  end
end
