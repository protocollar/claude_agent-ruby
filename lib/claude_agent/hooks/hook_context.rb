# frozen_string_literal: true

module ClaudeAgent
  # Context passed to hook callbacks
  #
  class HookContext < ImmutableRecord
    attribute :tool_use_id, default: nil
  end
end
