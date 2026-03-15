# One-Shot Queries

One-shot queries send a single prompt to the Claude Code CLI and return the response. No persistent connection or multi-turn state is maintained. For multi-turn conversations, see `Conversation`.

The SDK provides three query methods at increasing levels of control:

| Method                   | Returns               | Config integration         | Streaming            | Best for                             |
|--------------------------|-----------------------|----------------------------|----------------------|--------------------------------------|
| `ClaudeAgent.ask`        | `TurnResult`          | Yes (merges global config) | Block form           | Most applications                    |
| `ClaudeAgent.query_turn` | `TurnResult`          | No (explicit Options)      | Block + EventHandler | Custom transports, event dispatch    |
| `ClaudeAgent.query`      | `Enumerator<Message>` | No (explicit Options)      | Enumerator           | Full control over message processing |

## ClaudeAgent.ask

The primary entry point. Merges per-request keyword arguments with the global `Configuration`, builds an `Options` instance, and delegates to `query_turn`.

```ruby
turn = ClaudeAgent.ask("What is 2+2?")
puts turn.text   # => "4"
puts turn.cost   # => 0.002
```

### With configuration overrides

Keyword arguments override global config for this request only:

```ruby
turn = ClaudeAgent.ask("Fix the bug in auth.rb",
  model: "opus",
  max_turns: 5,
  permission_mode: "acceptEdits"
)
```

### With callbacks

Pass `on_*` lambdas to receive events as they stream in. The method still returns a `TurnResult` after the turn completes.

```ruby
turn = ClaudeAgent.ask("Explain Ruby GC",
  on_text: ->(text) { print text },
  on_tool_use: ->(tool) { puts "\nUsing: #{tool.name}" },
  on_result: ->(result) { puts "\nCost: $#{result.total_cost_usd}" }
)
```

Available callback keys correspond to `EventHandler` events: `on_text`, `on_thinking`, `on_tool_use`, `on_tool_result`, `on_result`, `on_assistant`, `on_stream_event`, `on_message` (catch-all), and others. See `EventHandler::EVENTS` for the full list.

### With streaming block

The block receives each raw message as it arrives:

```ruby
turn = ClaudeAgent.ask("Explain Ruby GC") do |msg|
  case msg
  when ClaudeAgent::AssistantMessage
    print msg.text
  when ClaudeAgent::ResultMessage
    puts "\nDone in #{msg.duration_ms}ms"
  end
end
```

### With explicit Options

Pass a pre-built `Options` to bypass the global `Configuration` entirely:

```ruby
opts = ClaudeAgent::Options.new(
  model: "claude-sonnet-4-5-20250514",
  max_turns: 3,
  permission_mode: "acceptEdits",
  tools: ["Read", "Bash"]
)

turn = ClaudeAgent.ask("List files in /tmp", options: opts)
```

### With global configuration

Set defaults once, then call `ask` without repeating them:

```ruby
ClaudeAgent.configure do |c|
  c.model = "opus"
  c.max_turns = 10
  c.permission_mode = "acceptEdits"
end

# These calls inherit the global config
turn = ClaudeAgent.ask("Fix the failing test")
turn = ClaudeAgent.ask("Now update the docs", max_turns: 3)  # override max_turns
```

## ClaudeAgent.query_turn

Wraps `query` and accumulates all messages into a `TurnResult`. Use this when you need to pass an explicit `Options` or `EventHandler` without going through `Configuration`.

```ruby
def query_turn(prompt:, options: nil, transport: nil, events: nil, &block)
```

### Basic usage

```ruby
turn = ClaudeAgent.query_turn(prompt: "What is 2+2?")
puts turn.text
puts turn.cost
```

### With EventHandler

Build an `EventHandler` for typed event dispatch:

```ruby
events = ClaudeAgent::EventHandler.new
  .on_text { |text| print text }
  .on_tool_use { |tool| puts "Tool: #{tool.name}" }
  .on_result { |r| puts "\nCost: $#{r.total_cost_usd}" }

turn = ClaudeAgent.query_turn(
  prompt: "Refactor the parser",
  options: ClaudeAgent::Options.new(model: "opus", max_turns: 5),
  events: events
)
```

### With block

The block receives each message, just like the block form of `ask`:

```ruby
turn = ClaudeAgent.query_turn(prompt: "Explain closures") do |msg|
  print msg.text if msg.is_a?(ClaudeAgent::AssistantMessage)
end

puts turn.session_id
```

### With custom transport

Inject a transport for testing or custom subprocess management:

```ruby
transport = ClaudeAgent::Transport::Subprocess.new(options: opts)
turn = ClaudeAgent.query_turn(prompt: "Hello", options: opts, transport: transport)
```

## ClaudeAgent.query

The lowest-level one-shot interface. Returns an `Enumerator` that yields each `Message` as it arrives from the CLI. You are responsible for iterating and interpreting message types.

```ruby
def query(prompt:, options: nil, transport: nil)
```

### Basic usage with case statement

```ruby
ClaudeAgent.query(prompt: "What is 2+2?").each do |message|
  case message
  when ClaudeAgent::SystemMessage
    # Init message with session metadata
  when ClaudeAgent::AssistantMessage
    print message.text
  when ClaudeAgent::UserMessage
    # Tool results (system-generated)
  when ClaudeAgent::StreamEvent
    # Streaming deltas
  when ClaudeAgent::ResultMessage
    puts "\nCost: $#{message.total_cost_usd}"
    puts "Duration: #{message.duration_ms}ms"
    puts "Session: #{message.session_id}"
  end
end
```

### Collecting all messages

```ruby
messages = ClaudeAgent.query(prompt: "Hello").to_a
result = messages.find { |m| m.is_a?(ClaudeAgent::ResultMessage) }
puts result.total_cost_usd
```

### With custom options

```ruby
options = ClaudeAgent::Options.new(
  model: "claude-sonnet-4-5-20250514",
  max_turns: 5,
  permission_mode: "acceptEdits"
)

ClaudeAgent.query(prompt: "Fix the bug", options: options).each do |message|
  # ...
end
```

## TurnResult

All three methods ultimately produce a `TurnResult` (for `query`, you build one yourself or use `query_turn`). Key accessors:

| Accessor          | Type            | Description                                 |
|-------------------|-----------------|---------------------------------------------|
| `text`            | `String`        | All assistant text concatenated             |
| `thinking`        | `String`        | All thinking content concatenated           |
| `tool_uses`       | `Array`         | Tool use blocks from assistant messages     |
| `tool_results`    | `Array`         | Tool result blocks from user messages       |
| `tool_executions` | `Array<Hash>`   | Matched `{ tool_use:, tool_result: }` pairs |
| `result`          | `ResultMessage` | Final result message (nil if incomplete)    |
| `cost`            | `Float`         | Total cost in USD                           |
| `usage`           | `Hash`          | Token usage breakdown                       |
| `duration_ms`     | `Integer`       | Wall-clock duration                         |
| `session_id`      | `String`        | Session ID for resumption                   |
| `model`           | `String`        | Model used                                  |
| `success?`        | `Boolean`       | Whether the turn completed without error    |
| `error?`          | `Boolean`       | Whether the turn ended with an error        |
| `messages`        | `Array`         | All raw messages received                   |

## Choosing the Right Method

**Use `ask`** when you want the simplest path with global configuration support. This is the right choice for most applications.

**Use `query_turn`** when you need explicit `Options` or `EventHandler` without going through `Configuration`, or when injecting a custom transport.

**Use `query`** when you need full control over message iteration -- for example, to build custom accumulators, forward messages to another system, or handle message types that `TurnResult` does not expose.
