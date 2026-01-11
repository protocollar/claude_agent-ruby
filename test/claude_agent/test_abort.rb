# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentAbortController < ActiveSupport::TestCase
  test "abort_controller_initialization" do
    controller = ClaudeAgent::AbortController.new
    refute controller.signal.aborted?
    assert_nil controller.signal.reason
  end

  test "abort_sets_signal" do
    controller = ClaudeAgent::AbortController.new
    controller.abort("User cancelled")

    assert controller.signal.aborted?
    assert_equal "User cancelled", controller.signal.reason
  end

  test "abort_default_reason" do
    controller = ClaudeAgent::AbortController.new
    controller.abort

    assert controller.signal.aborted?
    assert_equal "Operation was aborted", controller.signal.reason
  end

  test "signal_check_raises_when_aborted" do
    controller = ClaudeAgent::AbortController.new
    controller.abort("Test abort")

    error = assert_raises(ClaudeAgent::AbortError) do
      controller.signal.check!
    end
    assert_match(/Test abort/, error.message)
  end

  test "signal_check_does_not_raise_when_not_aborted" do
    controller = ClaudeAgent::AbortController.new
    assert_nothing_raised { controller.signal.check! }
  end

  test "on_abort_callback" do
    controller = ClaudeAgent::AbortController.new
    callback_reason = nil

    controller.signal.on_abort { |reason| callback_reason = reason }
    controller.abort("Callback test")

    assert_equal "Callback test", callback_reason
  end

  test "on_abort_immediate_if_already_aborted" do
    controller = ClaudeAgent::AbortController.new
    controller.abort("Already done")

    callback_called = false
    controller.signal.on_abort { callback_called = true }

    assert callback_called
  end

  test "abort_is_idempotent" do
    controller = ClaudeAgent::AbortController.new
    controller.abort("First")
    controller.abort("Second")

    assert_equal "First", controller.signal.reason
  end

  test "signal_wait_with_timeout" do
    controller = ClaudeAgent::AbortController.new

    result = controller.signal.wait(timeout: 0.01)
    refute result
  end

  test "signal_wait_returns_on_abort" do
    controller = ClaudeAgent::AbortController.new

    Thread.new { sleep(0.01); controller.abort }
    result = controller.signal.wait(timeout: 1)

    assert result
  end

  test "multiple_on_abort_callbacks" do
    controller = ClaudeAgent::AbortController.new
    results = []

    controller.signal.on_abort { results << 1 }
    controller.signal.on_abort { results << 2 }
    controller.signal.on_abort { results << 3 }

    controller.abort

    assert_equal [ 1, 2, 3 ], results
  end
end

class TestClaudeAgentAbortError < ActiveSupport::TestCase
  test "abort_error_inheritance" do
    error = ClaudeAgent::AbortError.new("test")
    assert_kind_of ClaudeAgent::Error, error
    assert_kind_of StandardError, error
  end

  test "abort_error_default_message" do
    error = ClaudeAgent::AbortError.new
    assert_equal "Operation was aborted", error.message
  end
end

class TestClaudeAgentOptionsAbortController < ActiveSupport::TestCase
  test "options_accepts_abort_controller" do
    controller = ClaudeAgent::AbortController.new
    options = ClaudeAgent::Options.new(abort_controller: controller)

    assert_equal controller, options.abort_controller
    assert_equal controller.signal, options.abort_signal
  end

  test "options_abort_signal_nil_without_controller" do
    options = ClaudeAgent::Options.new
    assert_nil options.abort_signal
  end
end
