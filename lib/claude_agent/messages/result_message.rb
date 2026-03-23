# frozen_string_literal: true

module ClaudeAgent
  # Result message (final message with usage/cost info) - TypeScript SDK parity
  #
  # @example Success result
  #   msg = ResultMessage.new(
  #     subtype: "success",
  #     duration_ms: 1500,
  #     duration_api_ms: 1200,
  #     is_error: false,
  #     num_turns: 3,
  #     session_id: "session-abc",
  #     total_cost_usd: 0.05,
  #     usage: {input_tokens: 100, output_tokens: 50}
  #   )
  #
  # @example Error result
  #   msg = ResultMessage.new(
  #     subtype: "error_max_turns",
  #     errors: ["Maximum turns exceeded"],
  #     ...
  #   )
  #
  class ResultMessage < ImmutableRecord
    include Message

    attribute :subtype
    attribute :duration_ms
    attribute :duration_api_ms
    attribute :is_error
    attribute :num_turns
    attribute :session_id
    attribute :uuid, default: nil
    attribute :total_cost_usd, default: nil
    attribute :usage, default: nil
    attribute :result, default: nil
    attribute :structured_output, default: nil
    attribute :errors, default: nil             # Array<String> for error subtypes
    attribute :permission_denials, default: nil  # Array<SDKPermissionDenial>
    attribute :model_usage, default: nil         # Hash with per-model usage breakdown
    attribute :stop_reason, default: nil         # Why the model stopped generating (TypeScript SDK parity)
    attribute :fast_mode_state, default: nil     # Fast mode state (TypeScript SDK v0.2.63 parity)

    def type
      :result
    end

    # Check if this was an error result
    # @return [Boolean]
    def error?
      is_error
    end

    # Check if this was a successful result
    # @return [Boolean]
    def success?
      !is_error
    end
  end
end
