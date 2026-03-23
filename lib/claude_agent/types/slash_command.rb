# frozen_string_literal: true

module ClaudeAgent
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
