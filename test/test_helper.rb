# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "claude_agent"

require "active_support"
require "active_support/test_case"
require "minitest/autorun"
require "mocha/minitest"

# Auto-load test support files
Dir[File.join(__dir__, "support", "**", "*.rb")].each { |f| require f }

# Fixture helpers
def fixture_path(name)
  File.join(__dir__, "fixtures", name)
end

def read_fixture(name)
  File.read(fixture_path(name))
end

def json_fixture(name)
  JSON.parse(read_fixture("#{name}.json"))
end
