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

  # Return type for supported_commands() (TypeScript SDK parity)
  #
  # @example
  #   cmd = SlashCommand.new(name: "commit", description: "Create a commit", argument_hint: "[message]")
  #   cmd.name        # => "commit"
  #   cmd.description # => "Create a commit"
  #
  class SlashCommand < ImmutableRecord
    attribute :name
    attribute :description, default: nil
    attribute :argument_hint, default: nil
  end
end
