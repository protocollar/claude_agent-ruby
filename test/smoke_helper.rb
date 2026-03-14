# frozen_string_literal: true

require_relative "integration_helper"
require "net/http"

# Base class for smoke tests that run against a local LLM (e.g. Ollama).
#
# Skip mechanism:
#   - Set SMOKE=true to run smoke tests (automatic via `rake test_smoke`)
#   - Checks Ollama availability at ANTHROPIC_BASE_URL (default: localhost:11434)
#
# Usage:
#   class TestSmokeBasic < SmokeTestCase
#     test "basic query" do
#       result = ClaudeAgent.query(prompt: "Hello", options: test_options)
#       # ...
#     end
#   end
#
class SmokeTestCase < IntegrationTestCase
  # Default model for smoke tests. Override with SMOKE_MODEL env var.
  SMOKE_MODEL = ENV.fetch("SMOKE_MODEL", "qwen2.5")

  def setup
    skip "Set SMOKE=true to run smoke tests" unless ENV["SMOKE"] == "true"
    skip "Ollama not available" unless ollama_available?
    super
  end

  private

  # Override IntegrationTestCase#test_options to include the smoke model
  def test_options(**overrides)
    super(model: SMOKE_MODEL, **overrides)
  end

  def ollama_available?
    base_url = ENV.fetch("ANTHROPIC_BASE_URL", "http://localhost:11434")
    uri = URI.parse("#{base_url}/api/tags")
    response = Net::HTTP.get_response(uri)
    response.is_a?(Net::HTTPSuccess)
  rescue StandardError
    false
  end
end
