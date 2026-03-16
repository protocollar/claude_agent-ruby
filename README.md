# ClaudeAgent

Ruby SDK for building AI-powered applications with the [Claude Agent SDK](https://platform.claude.com/docs/en/agent-sdk/overview). Wraps the Claude Code CLI with idiomatic Ruby interfaces for one-shot queries, multi-turn conversations, permissions, hooks, and MCP tools.

## Requirements

- Ruby 3.2+ (uses `Data.define`)
- [Claude Code CLI](https://code.claude.com/docs/en/getting-started) v2.0.0+

## Installation

```ruby
gem "claude_agent"
```

## Quick Start

### One-Shot Query

```ruby
require "claude_agent"

turn = ClaudeAgent.ask("What is the capital of France?")
puts turn.text
puts "Cost: $#{turn.cost}"
```

### Multi-Turn Conversation

```ruby
ClaudeAgent.chat do |c|
  c.say("Fix the bug in auth.rb")
  c.say("Now add tests for the fix")
  puts "Total cost: $#{c.total_cost}"
end
```

### Streaming

```ruby
ClaudeAgent.ask("Explain Ruby blocks") { |msg| print msg.text_content }
```

### Global Configuration

```ruby
ClaudeAgent.configure do |c|
  c.model = "claude-sonnet-4-5-20250514"
  c.permission_mode = "acceptEdits"
  c.max_turns = 10
end

# Or set individual fields
ClaudeAgent.model = "claude-sonnet-4-5-20250514"
```

### Permissions

```ruby
ClaudeAgent.permissions do |p|
  p.allow "Read", "Grep", "Glob"
  p.deny "Bash", message: "Shell access disabled"
  p.deny_all
end
```

### Hooks

```ruby
ClaudeAgent.hooks do |h|
  h.before_tool_use(/Bash/) { |input, ctx| { continue_: true } }
  h.after_tool_use { |input, ctx| { continue_: true } }
end
```

### MCP Tools

```ruby
server = ClaudeAgent::MCP::Server.new(name: "calc") do |s|
  s.tool("add", "Add two numbers", { a: :number, b: :number }) do |args|
    args[:a] + args[:b]
  end
end

ClaudeAgent.register_mcp_server(server)
```

## Documentation

| Guide                                      | Description                                              |
|--------------------------------------------|----------------------------------------------------------|
| [Getting Started](docs/getting-started.md) | Installation, first queries, multi-turn basics           |
| [Configuration](docs/configuration.md)     | Global config, Options, sandbox, agents, env vars        |
| [Conversations](docs/conversations.md)     | Multi-turn API, TurnResult, callbacks, tool tracking     |
| [Queries](docs/queries.md)                 | One-shot interfaces: ask, query_turn, query              |
| [Permissions](docs/permissions.md)         | PermissionPolicy DSL, can_use_tool, queue mode           |
| [Hooks](docs/hooks.md)                     | HookRegistry DSL, hook events, input types               |
| [MCP Tools](docs/mcp.md)                   | In-process tools, servers, schemas, elicitation          |
| [Events](docs/events.md)                   | EventHandler, typed callbacks, event layers              |
| [Messages](docs/messages.md)               | All 22 message types, 8 content blocks, pattern matching |
| [Sessions](docs/sessions.md)               | Session discovery, mutations, forking, resume            |
| [Client](docs/client.md)                   | Low-level bidirectional API (advanced)                   |
| [Errors](docs/errors.md)                   | Error hierarchy and handling patterns                    |
| [Logging](docs/logging.md)                 | Debug logging, custom loggers, log levels                |
| [Architecture](docs/architecture.md)       | Internal design, data flow, module map                   |

## Development

```bash
bin/setup                          # Install dependencies
bundle exec rake                   # Tests + RBS + RuboCop
bundle exec rake test              # Unit tests
bundle exec rake test_integration  # Integration tests (requires CLI v2.0.0+)
bundle exec rubocop                # Lint
bin/console                        # IRB with gem loaded
```

## License

MIT License - see [LICENSE.txt](LICENSE.txt)
