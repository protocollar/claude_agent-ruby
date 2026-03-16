# Getting Started

This guide walks you through the ClaudeAgent Ruby SDK from first install to multi-turn conversations. Each section builds on the last, starting with the simplest API.

## Requirements

- **Ruby 3.2+** (the SDK uses `Data.define` for immutable types)
- **Claude Code CLI v2.0.0+** ([install guide](https://code.claude.com/docs/en/getting-started))

Verify both are available:

```bash
ruby -v    # >= 3.2.0
claude -v  # >= 2.0.0
```

## Installation

Add to your Gemfile:

```ruby
gem "claude_agent"
```

Then:

```bash
bundle install
```

Or install directly:

```bash
gem install claude_agent
```

## Your First Query

The fastest way to get a response is `ClaudeAgent.ask`. It sends a single prompt and returns a `TurnResult`:

```ruby
require "claude_agent"

turn = ClaudeAgent.ask("What is the capital of France?")
puts turn.text
# => "The capital of France is Paris."
```

`TurnResult` gives you structured access to everything that happened during the turn:

```ruby
turn = ClaudeAgent.ask("Explain Ruby's GIL in one sentence.")

puts turn.text           # Combined text from all assistant messages
puts turn.cost           # Total cost in USD (e.g., 0.003)
puts turn.duration_ms    # Wall-clock time in milliseconds
puts turn.session_id     # Session ID (for resuming later)
puts turn.model          # Model that handled the request
puts turn.tool_uses.size # Number of tools Claude invoked
puts turn.success?       # true if no errors
```

### Passing Options

Override defaults with keyword arguments:

```ruby
turn = ClaudeAgent.ask("Fix the bug in auth.rb",
  model: "opus",
  max_turns: 5,
  permission_mode: "acceptEdits"
)
```

## Streaming

Pass a block to `ask` to receive each message as it arrives:

```ruby
turn = ClaudeAgent.ask("Explain how TCP works") do |message|
  case message
  when ClaudeAgent::AssistantMessage
    print message.text
  when ClaudeAgent::ResultMessage
    puts "\n--- Done (cost: $#{message.total_cost_usd}) ---"
  end
end
```

The block receives every message in the protocol stream. The return value is still a `TurnResult` with the full accumulated data.

### Streaming with Callbacks

For cleaner streaming, use `on_stream` to receive just the text:

```ruby
turn = ClaudeAgent.ask("Write a haiku about Ruby",
  on_stream: ->(text) { print text }
)
puts "\nCost: $#{turn.cost}"
```

## Multi-Turn Conversations

Use `ClaudeAgent.chat` for back-and-forth conversations. The block form auto-closes the connection when done:

```ruby
ClaudeAgent.chat do |c|
  c.say("What files are in the current directory?")
  c.say("Which one is the largest?")
  c.say("Show me the first 10 lines of that file.")

  puts "Total cost: $#{c.total_cost}"
end
```

Each call to `say` returns a `TurnResult`:

```ruby
ClaudeAgent.chat(model: "opus") do |c|
  turn = c.say("Write a function that reverses a string")
  puts turn.text

  turn = c.say("Now add error handling")
  puts turn.text
  puts "Tools used: #{turn.tool_uses.map(&:name).join(", ")}"
end
```

### Without a Block

If you need the conversation to outlive a block, skip it:

```ruby
conversation = ClaudeAgent.chat(model: "sonnet")
conversation.say("Hello")
conversation.say("Tell me more")
conversation.close  # Always close when done
```

### Streaming in Conversations

Pass `on_stream` to print text as it arrives:

```ruby
ClaudeAgent.chat(on_stream: ->(text) { print text }) do |c|
  c.say("What is 2+2?")
  puts  # newline after streamed output
  c.say("Now multiply that by 10")
  puts
end
```

Or stream per-turn with a block on `say`:

```ruby
ClaudeAgent.chat do |c|
  c.say("Explain monads") do |message|
    print message.text if message.is_a?(ClaudeAgent::AssistantMessage)
  end
end
```

## Global Configuration

Set defaults that apply to every `ask` and `chat` call:

```ruby
ClaudeAgent.model = "opus"
ClaudeAgent.max_turns = 10
ClaudeAgent.permission_mode = "acceptEdits"
ClaudeAgent.system_prompt = "You are a helpful coding assistant."
```

Or configure in bulk:

```ruby
ClaudeAgent.configure do |c|
  c.model = "opus"
  c.max_turns = 10
  c.permission_mode = "acceptEdits"
  c.system_prompt = "You are a helpful coding assistant."
  c.max_budget_usd = 1.0
  c.cwd = "/path/to/project"
end
```

Per-request keyword arguments always override global defaults:

```ruby
ClaudeAgent.model = "sonnet"

# This request uses opus despite the global default
turn = ClaudeAgent.ask("Complex question", model: "opus")
```

Reset to defaults with:

```ruby
ClaudeAgent.reset_config!
```

See [Configuration](configuration.md) for the full list of options.

## The Conversation Class

For full control, use `ClaudeAgent::Conversation` directly. It supports callbacks, permission handling, tool tracking, and session management.

```ruby
conversation = ClaudeAgent::Conversation.open(
  model: "opus",
  max_turns: 10,
  permission_mode: "acceptEdits",
  on_stream: ->(text) { print text },
  on_tool_use: ->(tool) { puts "\nUsing tool: #{tool.name}" },
  on_result: ->(result) { puts "\nTurn cost: $#{result.total_cost_usd}" }
) do |c|
  c.say("Read the file config.rb and explain what it does")
  c.say("Refactor it to use keyword arguments")

  puts "Session: #{c.session_id}"
  puts "Total cost: $#{c.total_cost}"
  puts "Turns: #{c.turns.size}"
end
```

### Available Callbacks

| Callback         | Receives                        | When                                      |
|------------------|---------------------------------|-------------------------------------------|
| `on_stream`      | `String`                        | Each text chunk as it streams             |
| `on_text`        | `String`                        | Full text from each assistant message     |
| `on_thinking`    | `String`                        | Thinking/reasoning content                |
| `on_tool_use`    | `ToolUseBlock`                  | Claude requests a tool                    |
| `on_tool_result` | `ToolResultBlock, ToolUseBlock` | Tool result arrives (paired with request) |
| `on_result`      | `ResultMessage`                 | Turn completes                            |
| `on_message`     | `Message`                       | Every message (catch-all)                 |

### Permission Handling

By default, Conversation queues permission requests for you to handle. You can also set a mode or provide a custom callback:

```ruby
# Use a CLI permission mode
ClaudeAgent::Conversation.open(on_permission: :accept_edits) do |c|
  c.say("Fix the typo in README.md")
end

# Or provide a lambda
ClaudeAgent::Conversation.open(
  on_permission: ->(tool_name, input, ctx) {
    ClaudeAgent::PermissionResultAllow.new
  }
) do |c|
  c.say("Update the config file")
end
```

For declarative permission rules, see [Permissions](permissions.md).

## Resuming Sessions

Every turn returns a `session_id`. Save it to resume the conversation later:

```ruby
# First session
session_id = nil
ClaudeAgent.chat do |c|
  c.say("Let's work on the authentication module")
  session_id = c.session_id
end

# Later — resume where you left off
ClaudeAgent.resume_conversation(session_id) do |c|
  c.say("Continue with the tests we discussed")
end
```

`resume_conversation` returns a `Conversation`, so it supports the same block form and callbacks.

You can also resume via `Conversation.resume` directly:

```ruby
conversation = ClaudeAgent::Conversation.resume(session_id,
  on_stream: ->(text) { print text }
)
conversation.say("Pick up where we left off")
conversation.close
```

### Listing Past Sessions

Browse previous sessions without spawning a CLI process:

```ruby
sessions = ClaudeAgent.list_sessions(dir: "/path/to/project", limit: 10)
sessions.each do |session|
  puts "#{session.session_id}: #{session.title} (#{session.updated_at})"
end
```

## What's Next

- [Configuration](configuration.md) -- full list of options, permission modes, and sandbox settings
- [Conversations](conversations.md) -- advanced multi-turn patterns, tool tracking, and abort handling
- [Permissions](permissions.md) -- declarative permission policies and the `can_use_tool` callback
- [Hooks](hooks.md) -- lifecycle hooks for tool use, session events, and more
- [Messages](messages.md) -- all message types, content blocks, and the event system
- [MCP Servers](mcp-servers.md) -- integrating external tools via Model Context Protocol
- [Sessions](sessions.md) -- listing, reading, forking, and managing past sessions
