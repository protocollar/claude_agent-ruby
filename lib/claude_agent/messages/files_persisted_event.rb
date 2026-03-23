# frozen_string_literal: true

module ClaudeAgent
  # Files persisted event (TypeScript SDK v0.2.25 parity)
  #
  # Sent when files are persisted to storage during a session.
  # Contains lists of successfully persisted files and any failures.
  #
  # @example
  #   msg = FilesPersistedEvent.new(
  #     uuid: "msg-123",
  #     session_id: "session-abc",
  #     files: [{ filename: "test.rb", file_id: "file-456" }],
  #     failed: [],
  #     processed_at: "2026-01-30T12:00:00Z"
  #   )
  #   msg.files.first[:filename]  # => "test.rb"
  #
  class FilesPersistedEvent < ImmutableRecord
    include Message

    attribute :uuid
    attribute :session_id
    attribute :files, default: []
    attribute :failed, default: []
    attribute :processed_at, default: nil

    def type
      :files_persisted
    end
  end
end
