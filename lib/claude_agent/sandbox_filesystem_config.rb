# frozen_string_literal: true

module ClaudeAgent
  # Filesystem-specific configuration for sandbox mode (TypeScript SDK v0.2.77 parity)
  #
  # @example
  #   filesystem = SandboxFilesystemConfig.new(
  #     allow_write: ["/tmp/*"],
  #     deny_write: ["/etc/*"],
  #     deny_read: ["/secrets/*"],
  #     allow_read: ["/secrets/public/*"],
  #     allow_managed_read_paths_only: false
  #   )
  #
  class SandboxFilesystemConfig < ImmutableRecord
    attribute :allow_write, default: []
    attribute :deny_write, default: []
    attribute :deny_read, default: []
    attribute :allow_read, default: []
    attribute :allow_managed_read_paths_only, default: false

    def to_h
      result = {}
      result[:allowWrite] = allow_write unless allow_write.empty?
      result[:denyWrite] = deny_write unless deny_write.empty?
      result[:denyRead] = deny_read unless deny_read.empty?
      result[:allowRead] = allow_read unless allow_read.empty?
      result[:allowManagedReadPathsOnly] = allow_managed_read_paths_only if allow_managed_read_paths_only
      result
    end
  end
end
