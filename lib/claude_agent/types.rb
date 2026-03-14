# frozen_string_literal: true

require_relative "types/tools"
require_relative "types/models"
require_relative "types/mcp"
require_relative "types/sessions"
require_relative "types/operations"

module ClaudeAgent
  # Assistant message error types (TypeScript SDK parity)
  # Used to categorize errors returned by the assistant
  ASSISTANT_MESSAGE_ERROR_TYPES = %w[
    authentication_failed
    billing_error
    rate_limit
    invalid_request
    server_error
    unknown
    max_output_tokens
  ].freeze

  # API key source types (TypeScript SDK parity)
  # Indicates where the API key was sourced from
  API_KEY_SOURCES = %w[user project org temporary oauth].freeze
end
