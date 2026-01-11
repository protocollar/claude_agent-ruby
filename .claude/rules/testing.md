# Testing Conventions

SDK-specific testing guidance. For general patterns (base classes, mocking, structure), see `conventions.md`.

## Running Tests

```bash
bundle exec rake test                                    # Unit tests only
bundle exec rake test_integration                        # Integration tests (requires CLI v2.0.0+)
bundle exec rake test_all                                # All tests
bundle exec ruby -Itest test/claude_agent/test_foo.rb   # Single file

# Binstubs
bin/test                                                 # Unit tests only
bin/test-integration                                     # Integration tests
bin/test-all                                             # All tests
```

## Directory Structure

```
test/
├── test_helper.rb              # Central setup, requires, base class
├── integration_helper.rb       # Base class for integration tests
├── support/                    # Shared mocks, test transports, helpers
│   └── mock_transport.rb
├── claude_agent/               # Unit tests (mirrors lib/claude_agent/)
│   ├── test_client.rb
│   ├── test_options.rb
│   └── mcp/
│       └── test_tool.rb
├── integration/                # Integration tests (require Claude CLI)
│   ├── test_query.rb
│   ├── test_client.rb
│   └── ...
└── fixtures/                   # JSON fixtures for parser tests
    ├── assistant_message.json
    └── tool_use_response.json
```

## File Naming

| Component     | Convention                         |
|---------------|------------------------------------|
| Test files    | `test_{module}.rb`                 |
| Test classes  | `TestClaudeAgent{Module}`          |
| Support files | `mock_{name}.rb`, `fake_{name}.rb` |

## Extracting Test Support

Large mocks and fakes belong in `test/support/`, not inline:

```ruby
# test/support/mock_transport.rb
class MockTransport < ClaudeAgent::Transport::Base
  attr_reader :written_messages

  def initialize(responses: [])
    super()
    @responses = responses
    @written_messages = []
  end

  def write(data)
    @written_messages << JSON.parse(data)
  end

  def read_messages
    @responses.each { |r| yield r }
  end

  # ... minimal interface implementation
end
```

```ruby
# test/test_helper.rb
require "claude_agent"
require "minitest/autorun"
require "mocha/minitest"

Dir[File.join(__dir__, "support", "**", "*.rb")].each { |f| require f }
```

## Testing Data.define Types

This SDK uses `Data.define` for immutable message types:

```ruby
test "data type attributes" do
  block = ClaudeAgent::TextBlock.new(text: "hello")

  assert_equal "hello", block.text
  assert_equal :text, block.type
  assert block.frozen?
  assert_equal({ type: "text", text: "hello" }, block.to_h)
end

test "optional fields default to nil" do
  block = ClaudeAgent::ToolResultBlock.new(tool_use_id: "123")
  assert_nil block.content
  assert_nil block.is_error
end
```

## Testing String and Symbol Keys

JSON parses to string keys, Ruby prefers symbols. Always test both:

```ruby
test "accepts symbol keys" do
  block = ClaudeAgent::ImageContentBlock.new(
    source: { type: "base64", media_type: "image/png", data: "..." }
  )
  assert_equal "base64", block.source_type
end

test "accepts string keys" do
  block = ClaudeAgent::ImageContentBlock.new(
    source: { "type" => "base64", "media_type" => "image/png", "data" => "..." }
  )
  assert_equal "base64", block.source_type
end
```

## Fixtures vs Inline Data

**Use fixtures** for:
- Complex JSON structures reused across tests
- Large response payloads
- Realistic CLI output samples

**Use inline data** for:
- Simple, single-use test cases
- When the data structure IS the test (e.g., edge cases)

```ruby
# test/fixtures/assistant_with_tool_use.json
{
  "type": "assistant",
  "message": {
    "model": "claude",
    "content": [
      { "type": "text", "text": "Let me read that" },
      { "type": "tool_use", "id": "tool_123", "name": "Read", "input": {} }
    ]
  }
}
```

```ruby
# Usage
test "parses complex message" do
  data = json_fixture("assistant_with_tool_use")
  message = parser.parse(data)

  assert message.has_tool_use?
end
```

## Testing CLI Interaction

### Prefer Mocha over manual mocks

```ruby
test "spawns subprocess with correct args" do
  Process.expects(:spawn).with(
    "claude", "--print", "--output-format", "json",
    has_entries(chdir: Dir.pwd)
  ).returns(123)

  transport.start
end
```

### Use MockTransport for Client tests

```ruby
test "sends user message" do
  transport = MockTransport.new(responses: [result_message])
  client = ClaudeAgent::Client.new(transport: transport)
  client.connect

  client.send_message("Hello")

  assert_equal 1, transport.written_messages.size
  assert_equal "user", transport.written_messages.first["type"]
end
```

### Capturing I/O

Use Minitest's built-in `capture_io`:

```ruby
test "logs to stderr" do
  _, err = capture_io { client.send_message("test") }
  assert_match(/sending message/, err)
end
```

## Error Testing

Test error hierarchy and context fields:

```ruby
test "error includes context" do
  error = ClaudeAgent::ProcessError.new(
    "CLI failed",
    exit_code: 1,
    stderr: "error details"
  )

  assert_equal 1, error.exit_code
  assert_equal "error details", error.stderr
  assert_match(/CLI failed/, error.message)
end

test "error inheritance" do
  error = ClaudeAgent::ProcessError.new("test")
  assert_kind_of ClaudeAgent::Error, error
  assert_kind_of StandardError, error
end
```

## Integration Tests

Integration tests live in `test/integration/` and inherit from `IntegrationTestCase`:

```ruby
# test/integration/test_query.rb
require_relative "../integration_helper"

class TestIntegrationQuery < IntegrationTestCase
  test "real query returns result" do
    messages = ClaudeAgent.query(prompt: "Say hello", options: test_options).to_a
    result = messages.find { |m| m.is_a?(ClaudeAgent::ResultMessage) }

    assert_not_nil result
    assert result.success?
  end
end
```

The `IntegrationTestCase` base class:
- Skips tests unless `INTEGRATION=true` is set (automatic with `rake test_integration`)
- Skips if Claude CLI is not installed
- Provides `test_options` helper with sensible defaults

## What to Test

| Component      | Focus Areas                                 |
|----------------|---------------------------------------------|
| Options        | Default values, validation, CLI arg mapping |
| Messages       | Parsing, field access, type discrimination  |
| Content Blocks | All block types, to_h serialization         |
| Client         | Message sending, streaming, error handling  |
| Transport      | Process lifecycle, I/O handling             |
| Errors         | Hierarchy, context fields, messages         |
| MCP            | Tool definition, server config              |

## Test Coverage Guidelines

- High coverage on public API surface
- Don't test private methods directly—test through public interface
- Cover edge cases: nil values, empty collections, invalid input
- Test both success and failure paths
