# frozen_string_literal: true

module ClaudeAgent
  # Result of rewind_files() control method (TypeScript SDK parity)
  #
  # @example
  #   result = RewindFilesResult.new(
  #     can_rewind: true,
  #     files_changed: ["src/foo.rb", "src/bar.rb"],
  #     insertions: 10,
  #     deletions: 5
  #   )
  #
  class RewindFilesResult < ImmutableRecord
    attribute :can_rewind
    attribute :error, default: nil
    attribute :files_changed, default: nil
    attribute :insertions, default: nil
    attribute :deletions, default: nil
  end
end
