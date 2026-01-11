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
  end

  # Signal object that tracks abort state (TypeScript SDK parity)
  #
  # Thread-safe signal that can be checked by multiple consumers
  # and triggers callbacks when aborted.
  #
  class AbortSignal
    def initialize
      @aborted = false
      @reason = nil
      @mutex = Mutex.new
      @condition = ConditionVariable.new
      @callbacks = []
    end

    # Check if signal has been aborted
    # @return [Boolean]
    def aborted?
      @mutex.synchronize { @aborted }
    end

    # Get the abort reason
    # @return [String, nil]
    def reason
      @mutex.synchronize { @reason }
    end

    # Register a callback for when abort is triggered
    # @yield [reason] Called when abort occurs
    # @return [void]
    def on_abort(&block)
      @mutex.synchronize do
        if @aborted
          block.call(@reason)
        else
          @callbacks << block
        end
      end
    end

    # Wait until aborted (with optional timeout)
    # @param timeout [Numeric, nil] Timeout in seconds
    # @return [Boolean] True if aborted, false if timed out
    def wait(timeout: nil)
      @mutex.synchronize do
        return true if @aborted

        @condition.wait(@mutex, timeout)
        @aborted
      end
    end

    # Raise AbortError if aborted (for checking in loops)
    # @raise [AbortError] If signal has been aborted
    def check!
      raise AbortError, reason if aborted?
    end

    # @api private
    # Trigger the abort
    # @param reason [String, nil] Reason for aborting
    def abort!(reason = nil)
      callbacks_to_call = []
      @mutex.synchronize do
        return if @aborted

        @aborted = true
        @reason = reason || "Operation was aborted"
        callbacks_to_call = @callbacks.dup
        @callbacks.clear
        @condition.broadcast
      end
      callbacks_to_call.each { |cb| cb.call(@reason) }
    end
  end
end
