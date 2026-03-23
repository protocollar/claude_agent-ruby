# frozen_string_literal: true

module ClaudeAgent
  # Tools preset configuration (TypeScript SDK parity)
  #
  # @example
  #   preset = ToolsPreset.new(preset: "claude_code")
  #   options = ClaudeAgent::Options.new(tools: preset)
  #
  class ToolsPreset < ImmutableRecord
    attribute :type, default: "preset"
    attribute :preset, default: "claude_code"

    def to_h
      { type: type, preset: preset }
    end
  end
end
