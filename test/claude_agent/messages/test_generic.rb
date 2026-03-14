# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentMessagesGeneric < ActiveSupport::TestCase
  test "generic_message" do
    msg = ClaudeAgent::GenericMessage.new(
      message_type: "fancy_new",
      raw: { data: "hello", count: 42 }
    )
    assert_equal "fancy_new", msg.message_type
    assert_equal :fancy_new, msg.type
    assert_equal({ data: "hello", count: 42 }, msg.to_h)
  end

  test "generic_message_bracket_access" do
    msg = ClaudeAgent::GenericMessage.new(
      message_type: "fancy_new",
      raw: { data: "hello" }
    )
    assert_equal "hello", msg[:data]
  end

  test "generic_message_method_missing" do
    msg = ClaudeAgent::GenericMessage.new(
      message_type: "fancy_new",
      raw: { data: "hello", nested: { key: "value" } }
    )
    assert_equal "hello", msg.data
    assert_equal({ key: "value" }, msg.nested)
  end

  test "generic_message_respond_to_missing" do
    msg = ClaudeAgent::GenericMessage.new(
      message_type: "fancy_new",
      raw: { data: "hello" }
    )
    assert msg.respond_to?(:data)
    refute msg.respond_to?(:nonexistent)
  end

  test "generic_message_nil_type" do
    msg = ClaudeAgent::GenericMessage.new(message_type: nil, raw: {})
    assert_equal :unknown, msg.type
  end

  test "generic_message_in_types_constant" do
    assert_includes ClaudeAgent::MESSAGE_TYPES, ClaudeAgent::GenericMessage
  end
end
