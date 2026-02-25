# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentPermissionQueue < ActiveSupport::TestCase
  setup do
    @queue = ClaudeAgent::PermissionQueue.new
  end

  # --- Empty state ---

  test "starts empty" do
    assert @queue.empty?
    assert_equal 0, @queue.size
  end

  # --- push and poll ---

  test "push and poll" do
    request = build_request("Read")
    @queue.push(request)

    refute @queue.empty?
    assert_equal 1, @queue.size

    result = @queue.poll
    assert_equal request, result
    assert @queue.empty?
  end

  test "poll returns nil when empty" do
    assert_nil @queue.poll
  end

  test "multiple push and poll in order" do
    r1 = build_request("Read")
    r2 = build_request("Write")
    r3 = build_request("Bash")

    @queue.push(r1)
    @queue.push(r2)
    @queue.push(r3)

    assert_equal 3, @queue.size

    assert_equal r1, @queue.poll
    assert_equal r2, @queue.poll
    assert_equal r3, @queue.poll
    assert_nil @queue.poll
  end

  # --- pop with timeout ---

  test "pop blocks and returns request" do
    request = build_request("Read")

    Thread.new do
      sleep 0.05
      @queue.push(request)
    end

    result = @queue.pop(timeout: 2)
    assert_equal request, result
  end

  test "pop returns nil on timeout" do
    result = @queue.pop(timeout: 0.1)
    assert_nil result
  end

  # --- drain! ---

  test "drain empties queue and denies pending requests" do
    r1 = build_request("Read")
    r2 = build_request("Write")
    @queue.push(r1)
    @queue.push(r2)

    drained = @queue.drain!(reason: "Shutting down")

    assert @queue.empty?
    assert_equal 2, drained.size
    assert r1.resolved?
    assert r2.resolved?
    assert_equal "deny", r1.result.behavior
    assert_equal "Shutting down", r1.result.message
    assert_equal "deny", r2.result.behavior
  end

  test "drain skips already resolved requests" do
    request = build_request("Read")
    request.allow!
    @queue.push(request)

    drained = @queue.drain!

    assert_equal 1, drained.size
    assert_equal "allow", request.result.behavior, "Should remain allowed, not overwritten to deny"
  end

  test "drain on empty queue" do
    drained = @queue.drain!
    assert_equal [], drained
  end

  # --- size ---

  test "size tracks pushes and polls" do
    assert_equal 0, @queue.size

    @queue.push(build_request("Read"))
    assert_equal 1, @queue.size

    @queue.push(build_request("Write"))
    assert_equal 2, @queue.size

    @queue.poll
    assert_equal 1, @queue.size
  end

  private

  def build_request(tool_name)
    ClaudeAgent::PermissionRequest.new(
      tool_name: tool_name,
      input: {},
      context: nil,
      request_id: SecureRandom.hex(4)
    )
  end
end
