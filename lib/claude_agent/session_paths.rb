# frozen_string_literal: true

require "timeout"

module ClaudeAgent
  # Shared path/directory infrastructure for session discovery.
  #
  # Provides methods to locate Claude Code session files on disk,
  # encode project directory paths, and resolve git worktrees.
  # Used by both ListSessions and GetSessionMessages.
  #
  module SessionPaths
    MAX_SLUG_LENGTH = 200
    UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

    module_function

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

    # Resolve symlinks and normalize a path.
    #
    # @param path [String]
    # @return [String]
    def realpath(path)
      resolved = File.realpath(path)
      resolved = resolved.encode("UTF-8") unless resolved.encoding == Encoding::UTF_8
      resolved.unicode_normalize(:nfc)
    rescue SystemCallError
      safe = path.encode("UTF-8") rescue path
      safe.unicode_normalize(:nfc) rescue safe
    end

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
  end
end
