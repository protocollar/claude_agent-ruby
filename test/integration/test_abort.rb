# frozen_string_literal: true

require_relative "../integration_helper"

class TestIntegrationAbort < IntegrationTestCase
  test "AbortController functionality" do
    controller = ClaudeAgent::AbortController.new

    assert !controller.signal.aborted?, "Expected not aborted initially"
    assert controller.signal.reason.nil?, "Expected nil reason initially"

    controller.abort("User cancelled")
    assert controller.signal.aborted?, "Expected aborted after abort"
    assert_equal "User cancelled", controller.signal.reason

    assert_raises(ClaudeAgent::AbortError) do
      controller.signal.check!
    end

    # Test idempotency - should keep first reason
    controller.abort("Second reason")
    assert_equal "User cancelled", controller.signal.reason
  end

  test "AbortController with Client" do
    controller = ClaudeAgent::AbortController.new
    options = ClaudeAgent::Options.new(
      max_turns: 1,
      abort_controller: controller
    )

    assert_equal controller, options.abort_controller
    assert_equal controller.signal, options.abort_signal

    client = ClaudeAgent::Client.new(options: options)
    assert client.respond_to?(:abort!), "Client should have abort! method"
  end
end
