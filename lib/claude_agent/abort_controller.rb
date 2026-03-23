# frozen_string_literal: true

module ClaudeAgent
  # Controller for aborting operations (TypeScript SDK parity)
  #
  # Provides a Ruby-idiomatic way to cancel ongoing SDK operations.
  # Similar to JavaScript's AbortController pattern.
  #
  # @example Basic usage
  #   controller = AbortController.new
  #
  #   Thread.new { sleep(5); controller.abort("Timeout") }
  #
  #   ClaudeAgent.query(
  #     prompt: "Long running task",
  #     options: Options.new(abort_controller: controller)
  #   )
  #
  # @example With abort reason
  #   controller.abort("User cancelled")
  #   controller.signal.aborted?     # => true
  #   controller.signal.reason       # => "User cancelled"
  #
  class AbortController
    attr_reader :signal

    def initialize
      @signal = AbortSignal.new
    end

    # Abort the operation
    # @param reason [String, nil] Reason for aborting
    # @return [void]
    def abort(reason = nil)
      @signal.abort!(reason)
    end

    # Reset the controller so it can be reused for another turn.
    #
    # After calling {#abort}, the controller is in an aborted state
    # and cannot be reused without resetting. Call this before the
    # next operation, or use {Conversation} which auto-resets.
    #
    # @return [void]
    def reset!
      @signal.reset!
    end
  end
end
