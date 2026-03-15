# Events

The `EventHandler` dispatches typed events as messages flow through a conversation turn, replacing manual `case` statements over raw message types.

Three event layers fire for every message, in order:

1. **Catch-all** -- `:message` fires for every message regardless of type.
2. **Type-based** -- the message's `type` fires (e.g., `:assistant`, `:result`, `:stream_event`).
3. **Decomposed** -- convenience events extracted from rich content (`:text`, `:thinking`, `:tool_use`, `:tool_result`).

## Quick start

### Block DSL with `EventHandler.define`

Build a handler in a single expression using the block DSL. The block is evaluated in the context of the new handler, so `on_*` methods are available directly:

```ruby
handler = ClaudeAgent::EventHandler.define do
  on_text    { |text| print text }
  on_result  { |r| puts "\nCost: $#{r.total_cost_usd}" }
  on_tool_use { |tool| puts "Tool: #{tool.display_label}" }
end
```

Pass the handler to `query_turn`:

```ruby
turn = ClaudeAgent.query_turn(prompt: "Explain Ruby", events: handler)
```

### Traditional construction

Create an instance and chain `on_*` calls. Each returns `self`, so calls can be chained:

```ruby
handler = ClaudeAgent::EventHandler.new
  .on_text      { |text| print text }
  .on_thinking  { |thought| $stderr.puts "[thinking] #{thought}" }
  .on_tool_use  { |tool| puts "Using: #{tool.display_label}" }
  .on_result    { |r| puts "\nDone (cost=$#{r.total_cost_usd})" }
```

Or register handlers one at a time:

```ruby
handler = ClaudeAgent::EventHandler.new
handler.on_text { |text| print text }
handler.on_result { |r| puts "Done!" }
```

### Via Conversation

`Conversation.new` accepts `on_*` keyword arguments for any event. These are registered on the underlying `Client` and persist across turns:

```ruby
conversation = ClaudeAgent::Conversation.new(
  model: "claude-sonnet-4-5-20250514",
  on_text:          ->(text) { print text },
  on_thinking:      ->(thought) { $stderr.puts thought },
  on_tool_use:      ->(tool) { puts "Tool: #{tool.display_label}" },
  on_tool_result:   ->(result, tool_use) { puts "Result for #{tool_use&.name}" },
  on_result:        ->(r) { puts "\nCost: $#{r.total_cost_usd}" },
  on_message:       ->(msg) { log(msg) },
  on_stream_event:  ->(evt) { handle_stream(evt) },
  on_status:        ->(status) { show_status(status) },
  on_tool_progress: ->(prog) { update_spinner(prog) }
)

turn = conversation.say("Fix the bug in auth.rb")
conversation.close
```

`on_stream` is an alias for `on_text`:

```ruby
conversation = ClaudeAgent::Conversation.new(
  on_stream: ->(text) { print text }
)
```

### Via Client

Register event handlers directly on a `Client`. Handlers persist across turns and fire automatically during `receive_turn` and `send_and_receive`:

```ruby
client = ClaudeAgent::Client.new
client.on_text { |text| print text }
client.on_tool_use { |tool| puts "Using: #{tool.display_label}" }
client.on_result { |r| puts "\nDone!" }

client.connect
turn = client.send_and_receive("Fix the bug")
client.disconnect
```

The generic `on` method also works:

```ruby
client.on(:text) { |text| print text }
client.on(:stream_event) { |evt| handle_stream(evt) }
```

### Via one-shot query

Pass an `events:` keyword to `ClaudeAgent.query_turn` for one-shot queries:

```ruby
events = ClaudeAgent::EventHandler.define do
  on_text   { |text| print text }
  on_result { |r| puts "\nCost: $#{r.total_cost_usd}" }
end

turn = ClaudeAgent.query_turn(prompt: "Explain concurrency", events: events)
puts turn.text
```

The handler's `reset!` is called automatically when the turn completes.

## Standalone usage

Create a handler and dispatch messages manually with `handle`:

```ruby
handler = ClaudeAgent::EventHandler.new
handler.on_text { |text| print text }
handler.on_tool_use { |tool| log_tool(tool) }
handler.on_tool_result { |result, tool_use| log_result(result, tool_use) }

client.receive_response.each { |msg| handler.handle(msg) }
handler.reset!
```

`handle` fires events in order:

1. `:message` (catch-all)
2. `message.type` (type-based)
3. Decomposed events extracted from the message content

Call `reset!` between turns to clear internal state (pending tool use tracking). When used via `Client` or `query_turn`, this is called automatically.

## Tool use and tool result pairing

The handler tracks pending tool uses internally. When a `:tool_result` event fires, it receives both the result block and the original tool use block that triggered it:

```ruby
handler.on_tool_use do |tool|
  puts "Requested: #{tool.name} (#{tool.id})"
end

handler.on_tool_result do |result, tool_use|
  puts "Result for: #{tool_use&.name}"  # tool_use is the matched ToolUseBlock
  puts "Error: #{result.is_error}" if result.is_error
end
```

The `tool_use` argument is `nil` if no matching tool use was found (which should not happen in normal operation).

## Utility methods

### `has_handlers?`

Returns whether any handlers have been registered:

```ruby
handler = ClaudeAgent::EventHandler.new
handler.has_handlers?  # => false

handler.on_text { |t| print t }
handler.has_handlers?  # => true
```

### `reset!`

Clears turn-level tracking state (pending tool uses). Does not remove registered handlers:

```ruby
handler.reset!  # Clear pending tool uses between turns
```

## Event reference

### Meta events

| Event      | Receives           | Description                         |
|------------|--------------------|-------------------------------------|
| `:message` | Any message object | Fires for every message (catch-all) |

### Type-based events

Each fires when a message with the matching `type` is received. The handler receives the full message object.

| Event                   | Description                                           |
|-------------------------|-------------------------------------------------------|
| `:user`                 | User message                                          |
| `:assistant`            | Assistant message (contains text, thinking, tool use) |
| `:system`               | System message (init, session info)                   |
| `:result`               | End-of-turn result (cost, usage, session ID)          |
| `:stream_event`         | Raw stream event                                      |
| `:compact_boundary`     | Context window compaction boundary                    |
| `:status`               | Status update                                         |
| `:tool_progress`        | Tool execution progress                               |
| `:hook_response`        | Hook execution response                               |
| `:auth_status`          | Authentication status                                 |
| `:task_notification`    | Background task notification                          |
| `:hook_started`         | Hook execution started                                |
| `:hook_progress`        | Hook execution progress                               |
| `:tool_use_summary`     | Tool use summary                                      |
| `:task_started`         | Background task started                               |
| `:task_progress`        | Background task progress                              |
| `:rate_limit_event`     | Rate limit information                                |
| `:prompt_suggestion`    | Suggested follow-up prompt                            |
| `:files_persisted`      | File checkpoint persisted                             |
| `:elicitation_complete` | Elicitation completed                                 |
| `:local_command_output` | Local command output                                  |

### Decomposed events

Extracted from the content of assistant and user messages. These fire after the type-based event.

| Event          | Receives                                   | Description                                                             |
|----------------|--------------------------------------------|-------------------------------------------------------------------------|
| `:text`        | `String`                                   | Concatenated text from an assistant message                             |
| `:thinking`    | `String`                                   | Concatenated thinking from an assistant message                         |
| `:tool_use`    | `ToolUseBlock` or `ServerToolUseBlock`     | A tool use request from an assistant message                            |
| `:tool_result` | `ToolResultBlock`, `ToolUseBlock` or `nil` | A tool result from a user message, paired with its originating tool use |
