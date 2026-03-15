# frozen_string_literal: true

module ClaudeAgent
  # A deferred permission request that can be resolved from any thread.
  #
  # When the control protocol receives a can_use_tool request and
  # queue-based permissions are enabled, it creates a PermissionRequest
  # and enqueues it. The main/UI thread resolves it by calling
  # {#allow!} or {#deny!}, which unblocks the reader thread.
  #
  # @example Resolving from a UI thread
  #   request = client.pending_permission
  #   puts "Tool: #{request.tool_name}, Input: #{request.input}"
  #   request.allow!
  #
  # @example Denying with a reason
  #   request.deny!(message: "Not allowed in production")
  #
  # @example Hybrid mode — defer from a can_use_tool callback
  #   can_use_tool: ->(name, input, context) {
  #     if name == "Read"
  #       ClaudeAgent::PermissionResultAllow.new  # auto-allow reads
  #     else
  #       context.request.defer!  # defer writes/bash to the UI
  #     end
  #   }
  #
  class PermissionRequest
    attr_reader :tool_name, :input, :context, :request_id, :created_at

    def initialize(tool_name:, input:, context:, request_id:)
      @tool_name = tool_name
      @input = input
      @context = context
      @request_id = request_id
      @created_at = Time.now

      @mutex = Mutex.new
      @condition = ConditionVariable.new
      @resolved = false
      @deferred = false
      @result = nil
    end

    # Allow the tool to execute.
    #
    # @param updated_input [Hash, nil] Modified input to send to the tool
    # @param updated_permissions [Array<PermissionUpdate>, nil] Permission rule updates
    # @return [void]
    # @raise [Error] If already resolved
    def allow!(updated_input: nil, updated_permissions: nil)
      resolve!(PermissionResultAllow.new(
        updated_input: updated_input,
        updated_permissions: updated_permissions,
        tool_use_id: context&.tool_use_id
      ))
    end

    # Deny the tool execution.
    #
    # @param message [String] Reason for denial
    # @param interrupt [Boolean] Whether to interrupt the agent
    # @return [void]
    # @raise [Error] If already resolved
    def deny!(message: "", interrupt: false)
      resolve!(PermissionResultDeny.new(
        message: message,
        interrupt: interrupt,
        tool_use_id: context&.tool_use_id
      ))
    end

    # Mark this request as deferred (enqueue instead of resolving synchronously).
    #
    # Called from within a can_use_tool callback to signal that the
    # callback will not return an answer. The protocol will enqueue
    # the request and wait for {#allow!} or {#deny!} from another thread.
    #
    # @return [self]
    def defer!
      @mutex.synchronize { @deferred = true }
      self
    end

    # Check if this request was deferred by a callback.
    # @return [Boolean]
    def deferred?
      @mutex.synchronize { @deferred }
    end

    # Check if this request has been resolved.
    # @return [Boolean]
    def resolved?
      @mutex.synchronize { @resolved }
    end

    # Check if this request is still pending.
    # @return [Boolean]
    def pending?
      !resolved?
    end

    # Get the result (nil if not yet resolved).
    # @return [PermissionResultAllow, PermissionResultDeny, nil]
    def result
      @mutex.synchronize { @result }
    end

    # @api private
    # Block until resolved (called by ControlProtocol reader thread).
    #
    # @param timeout [Numeric, nil] Timeout in seconds
    # @return [PermissionResultAllow, PermissionResultDeny]
    # @raise [TimeoutError] If timeout expires before resolution
    def wait(timeout: nil)
      @mutex.synchronize do
        unless @resolved
          deadline = timeout ? Time.now + timeout : nil
          until @resolved
            remaining = deadline ? deadline - Time.now : nil
            if remaining && remaining <= 0
              raise TimeoutError.new(
                "Permission request timed out",
                request_id: request_id,
                timeout_seconds: timeout
              )
            end
            @condition.wait(@mutex, remaining ? [ remaining, 0.5 ].min : 0.5)
          end
        end
        @result
      end
    end

    # Human-readable label for the permission request.
    #
    # Delegates to {ToolUseBlock#display_label} formatting.
    #
    # @return [String]
    def display_label
      ToolUseBlock.new(id: "", name: tool_name, input: input || {}).display_label
    end

    # Detailed summary of the tool call.
    #
    # @param max [Integer] Maximum length before truncation
    # @return [String]
    def summary(max: 60)
      ToolUseBlock.new(id: "", name: tool_name, input: input || {}).summary(max: max)
    end

    def inspect
      status = resolved? ? "resolved(#{@result&.behavior})" : "pending"
      "#<#{self.class} tool=#{tool_name} status=#{status} age=#{(Time.now - created_at).round(1)}s>"
    end

    private

    def resolve!(result)
      @mutex.synchronize do
        raise Error, "Permission request already resolved" if @resolved
        @result = result
        @resolved = true
        @condition.broadcast
      end
    end
  end
end
