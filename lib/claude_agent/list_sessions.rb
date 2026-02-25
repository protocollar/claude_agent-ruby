# frozen_string_literal: true

require "json"

module ClaudeAgent
  # Discovers and lists past Claude Code sessions from disk.
  #
  # Reads session metadata directly from ~/.claude/projects/ without spawning
  # a CLI subprocess. Matches the TypeScript SDK's listSessions() behavior.
  #
  # @example List all sessions
  #   sessions = ClaudeAgent.list_sessions
  #   sessions.each { |s| puts "#{s.summary} (#{s.session_id})" }
  #
  # @example List sessions for a specific directory
  #   sessions = ClaudeAgent.list_sessions(dir: "/path/to/project", limit: 10)
  #
  module ListSessions
    # Constants matching TypeScript SDK
    MAX_SLUG_LENGTH = 200
    BUFFER_SIZE = 65_536 # 64KB
    UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

    # Patterns for filtering non-meaningful user prompts (matches TypeScript MM regex)
    META_MESSAGE_PATTERN = /\A(?:<local-command-stdout>|<session-start-hook>|<tick>|<goal>|\[Request interrupted by user[^\]]*\]|\s*<ide_opened_file>[\s\S]*<\/ide_opened_file>\s*\z|\s*<ide_selection>[\s\S]*<\/ide_selection>\s*\z)/

    # Pattern for extracting command names
    COMMAND_NAME_PATTERN = /<command-name>(.*?)<\/command-name>/

    class << self
      # List past sessions with metadata.
      #
      # @param dir [String, nil] Directory to scope sessions to (with worktree support).
      #   When nil, returns sessions from all projects.
      # @param limit [Integer, nil] Maximum number of sessions to return.
      # @return [Array<SessionInfo>] Sessions sorted by last_modified descending.
      def call(dir: nil, limit: nil)
        if dir
          list_for_directory(dir, limit)
        else
          list_all(limit)
        end
      end

      private

      # --- Directory Encoding ---

      # Encode a project directory path to a slug for the projects directory.
      # Matches the TypeScript SDK's q9 function exactly.
      #
      # @param path [String] Absolute directory path
      # @return [String] Encoded slug
      def encode_project_dir(path)
        slug = path.gsub(/[^a-zA-Z0-9]/, "-")
        return slug if slug.length <= MAX_SLUG_LENGTH

        hash = java_string_hash(path)
        "#{slug[0, MAX_SLUG_LENGTH]}-#{hash}"
      end

      # Java-style string hash (matches TypeScript DM function).
      # Computes hash = ((hash << 5) - hash + charCode) as 32-bit signed integer,
      # then returns absolute value in base 36.
      #
      # @param str [String]
      # @return [String] Base-36 hash
      def java_string_hash(str)
        hash = 0
        str.each_char do |c|
          hash = ((hash << 5) - hash + c.ord) & 0xFFFFFFFF
          # Convert to signed 32-bit integer
          hash -= 0x100000000 if hash >= 0x80000000
        end
        hash.abs.to_s(36)
      end

      # --- Config Paths ---

      # @return [String] Claude config directory
      def config_dir
        (ENV["CLAUDE_CONFIG_DIR"] || File.join(Dir.home, ".claude"))
      end

      # @return [String] Projects directory within config
      def projects_dir
        File.join(config_dir, "projects")
      end

      # Get the expected project directory path for a given working directory.
      #
      # @param path [String] Working directory
      # @return [String] Full path to project sessions directory
      def project_dir_for(path)
        File.join(projects_dir, encode_project_dir(path))
      end

      # --- Session File Reading ---

      # Read head and tail buffers from a session file.
      #
      # @param path [String] Path to .jsonl file
      # @return [Hash, nil] { mtime:, size:, head:, tail: } or nil on error
      def read_file_buffers(path)
        stat = File.stat(path)
        File.open(path, "r:UTF-8") do |f|
          head = f.read(BUFFER_SIZE)
          return nil if head.nil? || head.empty?

          tail_offset = [ 0, stat.size - BUFFER_SIZE ].max
          tail = if tail_offset > 0
            f.seek(tail_offset)
            f.read(BUFFER_SIZE) || head
          else
            head
          end

          { mtime: (stat.mtime.to_f * 1000).to_i, size: stat.size, head: head, tail: tail }
        end
      rescue SystemCallError
        nil
      end

      # --- JSON String Scanning ---
      # These match TypeScript's K9 (first occurrence) and V9 (last occurrence)
      # functions. They scan for JSON key-value pairs without full parsing.

      # Extract the first occurrence of a JSON string value for the given key.
      #
      # @param buffer [String] Text to scan
      # @param key [String] JSON key name
      # @return [String, nil] Extracted value or nil
      def extract_first(buffer, key)
        prefixes = [ "\"#{key}\":\"", "\"#{key}\": \"" ]
        prefixes.each do |prefix|
          idx = buffer.index(prefix)
          next unless idx

          start = idx + prefix.length
          pos = start
          while pos < buffer.length
            if buffer[pos] == "\\"
              pos += 2
              next
            end
            if buffer[pos] == '"'
              return unescape_json_string(buffer[start...pos])
            end
            pos += 1
          end
        end
        nil
      end

      # Extract the last occurrence of a JSON string value for the given key.
      #
      # @param buffer [String] Text to scan
      # @param key [String] JSON key name
      # @return [String, nil] Extracted value or nil
      def extract_last(buffer, key)
        prefixes = [ "\"#{key}\":\"", "\"#{key}\": \"" ]
        result = nil
        prefixes.each do |prefix|
          search_from = 0
          loop do
            idx = buffer.index(prefix, search_from)
            break unless idx

            start = idx + prefix.length
            pos = start
            while pos < buffer.length
              if buffer[pos] == "\\"
                pos += 2
                next
              end
              if buffer[pos] == '"'
                result = unescape_json_string(buffer[start...pos])
                break
              end
              pos += 1
            end
            search_from = pos + 1
          end
        end
        result
      end

      # Unescape a JSON string value (handles \\, \", \n, etc.).
      #
      # @param str [String]
      # @return [String]
      def unescape_json_string(str)
        return str unless str.include?("\\")

        JSON.parse("\"#{str}\"")
      rescue JSON::ParserError
        str
      end

      # --- First Prompt Extraction ---

      # Extract the first meaningful user prompt from the head buffer.
      # Matches TypeScript's mW function.
      #
      # @param head [String] First 64KB of the session file
      # @return [String, nil] First meaningful prompt or nil
      def extract_first_prompt(head)
        command_name = nil

        head.each_line do |line|
          line = line.chomp
          # Skip non-user messages (quick string check before parsing)
          next unless line.include?('"type":"user"') || line.include?('"type": "user"')
          # Skip tool results
          next if line.include?('"tool_result"')
          # Skip meta messages
          next if line.include?('"isMeta":true') || line.include?('"isMeta": true')
          # Skip compact summaries
          next if line.include?('"isCompactSummary":true') || line.include?('"isCompactSummary": true')

          parsed = JSON.parse(line)
          next unless parsed["type"] == "user"

          message = parsed["message"]
          next unless message

          content = message["content"]
          texts = extract_text_parts(content)

          texts.each do |text|
            cleaned = text.gsub("\n", " ").strip
            next if cleaned.empty?

            # Check for command name pattern
            match = COMMAND_NAME_PATTERN.match(cleaned)
            if match
              command_name ||= match[1]
              next
            end

            # Skip meta message patterns
            next if META_MESSAGE_PATTERN.match?(cleaned)

            # Truncate long prompts at 200 chars
            cleaned = "#{cleaned[0, 200].strip}\u2026" if cleaned.length > 200
            return cleaned
          end
        rescue JSON::ParserError
          next
        end

        command_name
      end

      # Extract text parts from message content (string or array of blocks).
      #
      # @param content [String, Array, nil]
      # @return [Array<String>]
      def extract_text_parts(content)
        case content
        when String
          [ content ]
        when Array
          content.filter_map do |block|
            block["text"] if block.is_a?(Hash) && block["type"] == "text" && block["text"].is_a?(String)
          end
        else
          []
        end
      end

      # --- Session Metadata Parsing ---

      # Parse a single session file into a SessionInfo.
      #
      # @param path [String] Path to .jsonl file
      # @param session_id [String] UUID extracted from filename
      # @return [SessionInfo, nil] Parsed session info or nil if filtered
      def parse_session_file(path, session_id)
        buffers = read_file_buffers(path)
        return nil unless buffers

        head = buffers[:head]
        tail = buffers[:tail]

        # Check first line only for sidechain
        first_newline = head.index("\n")
        first_line = first_newline ? head[0...first_newline] : head
        return nil if first_line.include?('"isSidechain":true') || first_line.include?('"isSidechain": true')

        # Filter team sessions
        return nil if extract_first(head, "teamName")

        # Extract metadata
        custom_title = extract_last(tail, "customTitle")
        first_prompt = extract_first_prompt(head)
        git_branch = extract_last(tail, "gitBranch") || extract_first(head, "gitBranch")
        cwd = extract_first(head, "cwd")

        # Build summary: customTitle > last summary > firstPrompt > "(session)"
        summary_from_file = extract_last(tail, "summary")
        summary = custom_title || summary_from_file || first_prompt || "(session)"

        SessionInfo.new(
          session_id: session_id,
          summary: summary,
          last_modified: buffers[:mtime],
          file_size: buffers[:size],
          custom_title: custom_title,
          first_prompt: first_prompt,
          git_branch: git_branch,
          cwd: cwd
        )
      end

      # --- Directory Scanning ---

      # Scan a project directory for session files.
      #
      # @param dir_path [String] Path to a project directory under ~/.claude/projects/
      # @return [Array<SessionInfo>] Parsed sessions (unfiltered duplicates possible)
      def scan_project_dir(dir_path)
        return [] unless File.directory?(dir_path)

        entries = Dir.entries(dir_path)
        sessions = []

        entries.each do |entry|
          next unless entry.end_with?(".jsonl")

          stem = entry[0...-6] # Remove .jsonl extension
          next unless UUID_PATTERN.match?(stem)

          full_path = File.join(dir_path, entry)
          session = parse_session_file(full_path, stem)
          sessions << session if session
        end

        sessions
      end

      # Look up the project directory for a given path, handling hash suffix fallback.
      # Matches TypeScript's tQ function.
      #
      # @param path [String] Working directory
      # @return [String, nil] Project directory path or nil
      def find_project_dir(path)
        expected = project_dir_for(path)
        return expected if File.directory?(expected)

        # Try prefix matching for hash-suffixed directories
        slug = encode_project_dir(path)
        return nil if slug.length <= MAX_SLUG_LENGTH

        prefix = slug[0, MAX_SLUG_LENGTH]
        base = projects_dir
        return nil unless File.directory?(base)

        Dir.entries(base).each do |entry|
          next if entry.start_with?(".")
          next unless File.directory?(File.join(base, entry))
          return File.join(base, entry) if entry.start_with?("#{prefix}-")
        end

        nil
      end

      # --- Worktree Support ---

      # Get git worktree paths for a directory.
      #
      # @param dir [String] Working directory
      # @return [Array<String>] Worktree paths
      def git_worktrees(dir)
        output = nil
        IO.popen([ "git", "worktree", "list", "--porcelain" ], chdir: dir, err: File::NULL) do |io|
          Timeout.timeout(5) { output = io.read }
        end

        return [] unless output

        output.lines
          .select { |line| line.start_with?("worktree ") }
          .map { |line| line[9..].strip.unicode_normalize(:nfc) }
      rescue SystemCallError, Timeout::Error, Errno::ENOENT
        []
      end

      # Resolve symlinks and normalize a path.
      #
      # @param path [String]
      # @return [String]
      def realpath(path)
        File.realpath(path).unicode_normalize(:nfc)
      rescue SystemCallError
        path.unicode_normalize(:nfc)
      end

      # --- Listing Modes ---

      # List sessions for a specific directory, including worktree siblings.
      # Matches TypeScript's bM function.
      #
      # @param dir [String]
      # @param limit [Integer, nil]
      # @return [Array<SessionInfo>]
      def list_for_directory(dir, limit)
        resolved = realpath(dir)
        worktrees = git_worktrees(resolved)

        # Simple case: not in a worktree (or single worktree)
        if worktrees.length <= 1
          project_dir = find_project_dir(resolved)
          return [] unless project_dir
          return sort_and_limit(scan_project_dir(project_dir), limit)
        end

        # Complex case: multiple worktrees - scan all related project directories
        base = projects_dir

        # Build prefix list from worktree paths (longest first for matching)
        prefixes = worktrees.map { |wt| { path: wt, prefix: encode_project_dir(wt) } }
        prefixes.sort_by! { |p| -p[:prefix].length }

        all_sessions = []
        seen_dirs = Set.new

        # First: sessions from the exact directory
        project_dir = find_project_dir(resolved)
        if project_dir
          seen_dirs.add(File.basename(project_dir))
          all_sessions.concat(scan_project_dir(project_dir))
        end

        # Then: scan all project directories matching worktree prefixes
        if File.directory?(base)
          Dir.entries(base).each do |entry|
            next if entry.start_with?(".")
            next if seen_dirs.include?(entry)
            entry_path = File.join(base, entry)
            next unless File.directory?(entry_path)

            prefixes.each do |p|
              prefix = p[:prefix]
              if entry == prefix || (prefix.length >= MAX_SLUG_LENGTH && entry.start_with?("#{prefix[0, MAX_SLUG_LENGTH]}-"))
                seen_dirs.add(entry)
                all_sessions.concat(scan_project_dir(entry_path))
                break
              end
            end
          end
        end

        sort_and_limit(deduplicate(all_sessions), limit)
      end

      # List sessions from all project directories.
      # Matches TypeScript's EM function.
      #
      # @param limit [Integer, nil]
      # @return [Array<SessionInfo>]
      def list_all(limit)
        base = projects_dir
        return [] unless File.directory?(base)

        all_sessions = []

        Dir.entries(base).each do |entry|
          next if entry.start_with?(".")
          dir_path = File.join(base, entry)
          next unless File.directory?(dir_path)
          all_sessions.concat(scan_project_dir(dir_path))
        end

        sort_and_limit(deduplicate(all_sessions), limit)
      end

      # --- Helpers ---

      # Deduplicate sessions by session_id, keeping the most recent.
      # Matches TypeScript's cW function.
      #
      # @param sessions [Array<SessionInfo>]
      # @return [Array<SessionInfo>]
      def deduplicate(sessions)
        by_id = {}
        sessions.each do |session|
          existing = by_id[session.session_id]
          if !existing || session.last_modified > existing.last_modified
            by_id[session.session_id] = session
          end
        end
        by_id.values
      end

      # Sort by last_modified descending and apply optional limit.
      # Matches TypeScript's E4 function.
      #
      # @param sessions [Array<SessionInfo>]
      # @param limit [Integer, nil]
      # @return [Array<SessionInfo>]
      def sort_and_limit(sessions, limit)
        sorted = sessions.sort_by { |s| -s.last_modified }
        limit ? sorted.first(limit) : sorted
      end
    end
  end
end
