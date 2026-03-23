# frozen_string_literal: true

module ClaudeAgent
  # Per-model usage statistics returned in result messages (TypeScript SDK parity)
  #
  # @example
  #   usage = ModelUsage.new(input_tokens: 100, output_tokens: 50, cost_usd: 0.01, max_output_tokens: 4096)
  #
  class ModelUsage < ImmutableRecord
    attribute :input_tokens, default: 0
    attribute :output_tokens, default: 0
    attribute :cache_read_input_tokens, default: 0
    attribute :cache_creation_input_tokens, default: 0
    attribute :web_search_requests, default: 0
    attribute :cost_usd, default: 0.0
    attribute :context_window, default: nil
    attribute :max_output_tokens, default: nil
  end
end
