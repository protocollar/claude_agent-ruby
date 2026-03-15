# frozen_string_literal: true

require "json"
require "securerandom"

module ClaudeAgent
  # Fork a session by creating a new session file with remapped UUIDs.
  #
  # Reads all JSONL entries from the source session, optionally truncates
  # at a given message UUID, remaps all UUIDs to fresh values, and writes
  # a new session file in the same project directory.
  #
  # @example Basic fork
  #   result = ClaudeAgent.fork_session("abc-123-...")
  #   puts result.session_id
  #
  # @example Fork with truncation and title
  #   result = ClaudeAgent.fork_session(
  #     "abc-123-...",
  #     up_to_message_id: "msg-456-...",
  #     title: "Forked conversation"
  #   )
  #
  module ForkSession
    UUID_FIELDS = %w[uuid parentUuid].freeze
    SESSION_ID_FIELDS = %w[session_id sessionId].freeze

    module_function

    # Fork a session, creating a new session file with remapped UUIDs.
    #
    # @param session_id [String] UUID of the source session
    # @param up_to_message_id [String, nil] If provided, truncate at this message UUID (inclusive)
    # @param title [String, nil] If provided, append a custom-title entry
    # @param dir [String, nil] Project directory to find the session in
    # @return [ForkSessionResult] Result with the new session ID
    # @raise [ArgumentError] If session_id is not a valid UUID
    # @raise [Error] If the session file is not found
    def call(session_id, up_to_message_id: nil, title: nil, dir: nil)
      SessionMutations.send(:validate_session_id!, session_id)

      source_path = SessionMutations.send(:find_session_file, session_id, dir: dir)
      raise Error, "Session not found: #{session_id}" unless source_path

      lines = File.readlines(source_path, chomp: true)
      entries = lines.filter_map do |line|
        next if line.strip.empty?
        JSON.parse(line)
      end

      # Truncate at up_to_message_id (inclusive)
      if up_to_message_id
        cut_index = entries.index { |e| e["uuid"] == up_to_message_id }
        raise ArgumentError, "Message not found: #{up_to_message_id}" unless cut_index
        entries = entries[0..cut_index]
      end

      # Generate new session ID and UUID map
      new_session_id = SecureRandom.uuid
      uuid_map = build_uuid_map(entries)

      # Remap all entries
      remapped = entries.map { |entry| remap_entry(entry, uuid_map, new_session_id) }

      # Append custom-title entry if requested
      if title
        remapped << {
          "type" => "custom-title",
          "customTitle" => title.to_s,
          "sessionId" => new_session_id
        }
      end

      # Write new session file in the same directory as the source
      dest_path = File.join(File.dirname(source_path), "#{new_session_id}.jsonl")
      File.open(dest_path, "w") do |f|
        remapped.each { |entry| f.write("#{JSON.generate(entry)}\n") }
      end

      ForkSessionResult.new(session_id: new_session_id)
    end

    # Build a map of old UUIDs to new UUIDs from all entries.
    # @param entries [Array<Hash>]
    # @return [Hash<String, String>]
    def build_uuid_map(entries)
      map = {}
      entries.each do |entry|
        UUID_FIELDS.each do |field|
          value = entry[field]
          next unless value.is_a?(String) && !value.empty?
          map[value] ||= SecureRandom.uuid
        end
      end
      map
    end

    # Remap UUID and session_id fields in an entry.
    # @param entry [Hash] Original entry
    # @param uuid_map [Hash<String, String>] Old UUID to new UUID mapping
    # @param new_session_id [String] New session ID
    # @return [Hash] Remapped entry
    def remap_entry(entry, uuid_map, new_session_id)
      result = entry.dup

      UUID_FIELDS.each do |field|
        result[field] = uuid_map[result[field]] if result.key?(field) && uuid_map.key?(result[field])
      end

      SESSION_ID_FIELDS.each do |field|
        result[field] = new_session_id if result.key?(field)
      end

      result
    end
  end
end
