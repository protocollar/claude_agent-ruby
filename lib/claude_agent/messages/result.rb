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
  ResultMessage = Data.define(
    :subtype,
    :duration_ms,
    :duration_api_ms,
    :is_error,
    :num_turns,
    :session_id,
    :uuid,
    :total_cost_usd,
    :usage,
    :result,
    :structured_output,
    :errors,             # Array<String> for error subtypes
    :permission_denials, # Array<SDKPermissionDenial>
    :model_usage,        # Hash with per-model usage breakdown
    :stop_reason,        # Why the model stopped generating (TypeScript SDK parity)
    :fast_mode_state     # Fast mode state (TypeScript SDK v0.2.63 parity)
  ) do
    def initialize(
      subtype:,
      duration_ms:,
      duration_api_ms:,
      is_error:,
      num_turns:,
      session_id:,
      uuid: nil,
      total_cost_usd: nil,
      usage: nil,
      result: nil,
      structured_output: nil,
      errors: nil,
      permission_denials: nil,
      model_usage: nil,
      stop_reason: nil,
      fast_mode_state: nil
    )
      super
    end

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
