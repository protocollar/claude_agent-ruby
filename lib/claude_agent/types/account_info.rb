# frozen_string_literal: true

module ClaudeAgent
  # Return type for account_info() (TypeScript SDK parity)
  #
  # @example
  #   info = AccountInfo.new(email: "user@example.com", organization: "Acme Corp")
  #
  class AccountInfo < ImmutableRecord
    attribute :email, default: nil
    attribute :organization, default: nil
    attribute :subscription_type, default: nil
    attribute :token_source, default: nil
    attribute :api_key_source, default: nil
  end
end
