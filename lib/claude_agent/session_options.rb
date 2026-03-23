# frozen_string_literal: true

module ClaudeAgent
  # V2 Session options (subset of full Options)
  # V2 API - UNSTABLE
  # @alpha
  #
  # @example
  #   options = SessionOptions.new(
  #     model: "claude-sonnet-4-5-20250929",
  #     permission_mode: "acceptEdits"
  #   )
  #
  class SessionOptions < ImmutableRecord
    attribute :model
    attribute :path_to_claude_code_executable, default: nil
    attribute :env, default: nil
    attribute :allowed_tools, default: nil
    attribute :disallowed_tools, default: nil
    attribute :can_use_tool, default: nil
    attribute :hooks, default: nil
    attribute :permission_mode, default: nil
  end
end
