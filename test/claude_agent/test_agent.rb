# frozen_string_literal: true

require "test_helper"

class TestClaudeAgent < ActiveSupport::TestCase
  test "that_it_has_a_version_number" do
    refute_nil ::ClaudeAgent::VERSION
  end

  test "it_does_something_useful" do
    assert true
  end
end
