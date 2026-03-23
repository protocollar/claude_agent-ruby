# frozen_string_literal: true

module ClaudeAgent
  # Return type for supported_models() (TypeScript SDK parity)
  #
  # @example
  #   model = ModelInfo.new(value: "claude-3-opus", display_name: "Claude 3 Opus", description: "Most capable")
  #   model.value        # => "claude-3-opus"
  #   model.display_name # => "Claude 3 Opus"
  #
  class ModelInfo < ImmutableRecord
    attribute :value
    attribute :display_name, default: nil
    attribute :description, default: nil
    attribute :supports_effort, default: nil
    attribute :supported_effort_levels, default: nil
    attribute :supports_adaptive_thinking, default: nil
    attribute :supports_fast_mode, default: nil
    attribute :supports_auto_mode, default: nil
  end
end
