# frozen_string_literal: true

module ClaudeAgent
  # Tools preset configuration (TypeScript SDK parity)
  #
  # @example
  #   preset = ToolsPreset.new(preset: "claude_code")
  #   options = ClaudeAgent::Options.new(tools: preset)
  #
  ToolsPreset = Data.define(:type, :preset) do
    def initialize(type: "preset", preset: "claude_code")
      super
    end

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
  SlashCommand = Data.define(:name, :description, :argument_hint) do
    def initialize(name:, description: nil, argument_hint: nil)
      super
    end
  end
end
