# frozen_string_literal: true

module ClaudeAgent
  # Thread-safe queue of pending permission requests.
  #
  # Provides both blocking and non-blocking access to permission
  # requests that need resolution from the main thread.
  #
  # @example Non-blocking poll in a UI timer
  #   while request = client.permission_queue.poll
  #     show_dialog(request)
  #   end
  #
  # @example Blocking wait
  #   request = client.permission_queue.pop  # blocks until available
  #   request.allow!
  #
  class PermissionQueue
    def initialize
      @queue = Queue.new
    end

    # Non-blocking poll for the next pending request.
    #
    # @return [PermissionRequest, nil] The next request, or nil if empty
    def poll
      @queue.pop(true)
    rescue ThreadError
      nil
    end

    # Blocking pop — waits for a request to arrive.
    #
    # @param timeout [Numeric, nil] Maximum seconds to wait (nil = wait forever)
    # @return [PermissionRequest, nil] The request, or nil if timed out
    def pop(timeout: nil)
      if timeout
        deadline = Time.now + timeout
        loop do
          request = poll
          return request if request
          remaining = deadline - Time.now
          return nil if remaining <= 0
          sleep([ remaining, 0.05 ].min)
        end
      else
        @queue.pop
      end
    end

    # Check if there are pending requests.
    # @return [Boolean]
    def empty?
      @queue.empty?
    end

    # Number of pending requests.
    # @return [Integer]
    def size
      @queue.size
    end

    # @api private
    # Push a request onto the queue (called by ControlProtocol).
    #
    # @param request [PermissionRequest]
    # @return [void]
    def push(request)
      @queue.push(request)
    end

    # Deny all pending requests and drain the queue.
    #
    # Used during abort/disconnect to unblock the reader thread.
    #
    # @param reason [String] Denial reason for all pending requests
    # @return [Array<PermissionRequest>] The drained requests
    def drain!(reason: "Operation aborted")
      requests = []
      while (request = poll)
        request.deny!(message: reason) unless request.resolved?
        requests << request
      end
      requests
    end
  end
end
