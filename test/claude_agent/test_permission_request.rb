# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentPermissionRequest < ActiveSupport::TestCase
  setup do
    @context = ClaudeAgent::ToolPermissionContext.new(
      tool_use_id: "tool-123",
      decision_reason: "Needs approval"
    )
    @request = ClaudeAgent::PermissionRequest.new(
      tool_name: "Bash",
      input: { command: "rm -rf /tmp/test" },
      context: @context,
      request_id: "req-abc"
    )
  end

  # --- Attributes ---

  test "attributes" do
    assert_equal "Bash", @request.tool_name
    assert_equal({ command: "rm -rf /tmp/test" }, @request.input)
    assert_equal @context, @request.context
    assert_equal "req-abc", @request.request_id
    assert_instance_of Time, @request.created_at
  end

  # --- Initial state ---

  test "starts pending" do
    assert @request.pending?
    refute @request.resolved?
    assert_nil @request.result
  end

  test "starts not deferred" do
    refute @request.deferred?
  end

  # --- allow! ---

  test "allow resolves the request" do
    @request.allow!

    assert @request.resolved?
    refute @request.pending?
    assert_instance_of ClaudeAgent::PermissionResultAllow, @request.result
    assert_equal "allow", @request.result.behavior
  end

  test "allow with updated_input" do
    @request.allow!(updated_input: { command: "ls /tmp" })

    result = @request.result
    assert_equal({ command: "ls /tmp" }, result.updated_input)
  end

  test "allow with updated_permissions" do
    perms = [ ClaudeAgent::PermissionUpdate.new(type: "addRules", rules: [], behavior: "allow") ]
    @request.allow!(updated_permissions: perms)

    assert_equal perms, @request.result.updated_permissions
  end

  test "allow sets tool_use_id from context" do
    @request.allow!

    assert_equal "tool-123", @request.result.tool_use_id
  end

  # --- deny! ---

  test "deny resolves the request" do
    @request.deny!(message: "Not allowed")

    assert @request.resolved?
    assert_instance_of ClaudeAgent::PermissionResultDeny, @request.result
    assert_equal "deny", @request.result.behavior
    assert_equal "Not allowed", @request.result.message
  end

  test "deny with interrupt" do
    @request.deny!(message: "Blocked", interrupt: true)

    assert @request.result.interrupt
  end

  test "deny defaults" do
    @request.deny!

    assert_equal "", @request.result.message
    assert_equal false, @request.result.interrupt
  end

  # --- Double resolution ---

  test "allow after allow raises" do
    @request.allow!

    assert_raises(ClaudeAgent::Error) { @request.allow! }
  end

  test "deny after allow raises" do
    @request.allow!

    assert_raises(ClaudeAgent::Error) { @request.deny! }
  end

  test "allow after deny raises" do
    @request.deny!

    assert_raises(ClaudeAgent::Error) { @request.allow! }
  end

  # --- defer! ---

  test "defer marks request as deferred" do
    result = @request.defer!

    assert @request.deferred?
    assert_equal @request, result, "defer! returns self for chaining"
  end

  # --- wait ---

  test "wait returns result when already resolved" do
    @request.allow!

    result = @request.wait(timeout: 1)

    assert_instance_of ClaudeAgent::PermissionResultAllow, result
  end

  test "wait blocks until resolved from another thread" do
    resolved_result = nil

    thread = Thread.new do
      resolved_result = @request.wait(timeout: 5)
    end

    sleep 0.05
    @request.allow!
    thread.join(2)

    assert_instance_of ClaudeAgent::PermissionResultAllow, resolved_result
  end

  test "wait times out" do
    assert_raises(ClaudeAgent::TimeoutError) do
      @request.wait(timeout: 0.1)
    end
  end

  # --- inspect ---

  test "inspect pending" do
    output = @request.inspect
    assert_match(/PermissionRequest/, output)
    assert_match(/tool=Bash/, output)
    assert_match(/status=pending/, output)
  end

  test "inspect resolved" do
    @request.allow!
    output = @request.inspect
    assert_match(/status=resolved\(allow\)/, output)
  end

  # --- nil context ---

  test "allow with nil context" do
    request = ClaudeAgent::PermissionRequest.new(
      tool_name: "Read",
      input: {},
      context: nil,
      request_id: "req-nil"
    )
    request.allow!

    assert_nil request.result.tool_use_id
  end

  # --- Thread safety ---

  test "concurrent resolution attempts" do
    errors = []
    threads = 10.times.map do
      Thread.new do
        @request.allow!
      rescue ClaudeAgent::Error => e
        errors << e
      end
    end
    threads.each(&:join)

    assert @request.resolved?
    assert_equal 9, errors.size, "9 of 10 threads should get double-resolution error"
  end
end
