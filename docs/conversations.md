# Conversations

The `Conversation` class is the primary interface for multi-turn interactions with Claude. It manages the full lifecycle of a conversation: connecting to the CLI, sending messages, tracking turns, accumulating tool activity, and cleaning up resources.

Under the hood, `Conversation` wraps a `Client` and composes `TurnResult`, `EventHandler`, `CumulativeUsage`, and `PermissionQueue` into a single stateful object. It auto-connects on the first call to `say`, tracks multi-turn history, and builds a unified tool activity timeline across all turns.

## Creating a Conversation

There are several ways to create a conversation, depending on how much control you need over its lifecycle.

### `ClaudeAgent.chat`

The top-level entry point. Merges global configuration defaults automatically.

```ruby
# Block form -- auto-closes when the block exits
ClaudeAgent.chat(model: "claude-sonnet-4-5-20250514") do |c|
  c.say("Hello")
  c.say("Goodbye")
end

# Without a block -- caller is responsible for closing
c = ClaudeAgent.chat(model: "claude-sonnet-4-5-20250514")
c.say("Hello")
c.close
```

### `ClaudeAgent.conversation`

Creates a `Conversation` without merging global configuration defaults. Accepts the same keyword arguments as `Conversation.new`.

```ruby
c = ClaudeAgent.conversation(max_turns: 5)
c.say("Help me debug this")
c.close
```

### `Conversation.new`

Direct instantiation. Accepts all `Options` keyword arguments plus conversation-level callbacks (any `on_*` keyword).

```ruby
conversation = ClaudeAgent::Conversation.new(
  model: "claude-sonnet-4-5-20250514",
  max_turns: 10,
  on_text: ->(text) { print text },
  on_result: ->(result) { puts "\nCost: $#{result.total_cost_usd}" }
)
turn = conversation.say("Fix the bug in auth.rb")
conversation.close
```

### `Conversation.open`

Block form with automatic cleanup. The conversation is closed when the block exits, even if an exception is raised.

```ruby
ClaudeAgent::Conversation.open(permission_mode: "default") do |c|
  c.say("Help me write a function")
  c.say("Now add tests")
  puts "Total cost: $#{c.total_cost}"
end
```

## Sending Messages

Use `say` to send a message and receive the complete turn result. The conversation auto-connects on the first call.

```ruby
conversation = ClaudeAgent::Conversation.new(max_turns: 5)

turn = conversation.say("Fix the bug in auth.rb")
puts turn.text
puts "Tools used: #{turn.tool_uses.size}"
```

### Block Form for Streaming

Pass a block to `say` to receive each message as it streams in.

```ruby
conversation.say("Explain how authentication works") do |message|
  case message
  when ClaudeAgent::AssistantMessage
    print message.text
  when ClaudeAgent::ResultMessage
    puts "\nDone! Cost: $#{message.total_cost_usd}"
  end
end
```

### Multiple Turns

Each call to `say` is a new turn. Context is preserved across the conversation.

```ruby
ClaudeAgent::Conversation.open(max_turns: 3) do |c|
  c.say("Remember the secret word: PINEAPPLE")
  turn = c.say("What was the secret word?")
  puts turn.text  # => "PINEAPPLE"
  puts c.turns.size  # => 2
end
```

## TurnResult

Every call to `say` returns a `TurnResult` -- an accumulation of all messages received during that turn. It provides convenient accessors so you never need to write `case` statements over raw message types.

### Text and Thinking

| Method     | Return Type | Description                                                                                                                                                       |
|------------|-------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `text`     | `String`    | All text content concatenated across assistant messages. Falls back to accumulated streaming deltas if the turn was aborted before an `AssistantMessage` arrived. |
| `thinking` | `String`    | All thinking content concatenated across assistant messages.                                                                                                      |

```ruby
turn = conversation.say("Explain Ruby blocks")
puts turn.text
puts "Thinking: #{turn.thinking}" unless turn.thinking.empty?
```

### Tool Use

| Method            | Return Type                                     | Description                                                                              |
|-------------------|-------------------------------------------------|------------------------------------------------------------------------------------------|
| `tool_uses`       | `Array<ToolUseBlock, ServerToolUseBlock>`       | All tool use blocks across all assistant messages.                                       |
| `tool_results`    | `Array<ToolResultBlock, ServerToolResultBlock>` | All tool result blocks from user messages (system-generated tool responses).             |
| `tool_executions` | `Array<Hash>`                                   | Tool use/result pairs matched by ID. Each entry has `:tool_use` and `:tool_result` keys. |

```ruby
turn = conversation.say("Read the config file and fix the typo")

turn.tool_uses.each do |tool|
  puts "Used: #{tool.display_label}"
end

turn.tool_executions.each do |exec|
  puts "#{exec[:tool_use].name}: #{exec[:tool_result]&.content&.to_s&.slice(0, 80)}"
end
```

### Result Accessors

These delegate to the underlying `ResultMessage`. They return `nil` if the turn is still in progress.

| Method              | Return Type    | Description                                   |
|---------------------|----------------|-----------------------------------------------|
| `cost`              | `Float, nil`   | Total cost in USD for this turn.              |
| `duration_ms`       | `Integer, nil` | Wall-clock duration in milliseconds.          |
| `duration_api_ms`   | `Integer, nil` | API-only duration in milliseconds.            |
| `session_id`        | `String, nil`  | Session ID for resumption.                    |
| `model`             | `String, nil`  | Model used (from first assistant message).    |
| `stop_reason`       | `String, nil`  | Why the model stopped generating.             |
| `usage`             | `Hash, nil`    | Token usage breakdown.                        |
| `model_usage`       | `Hash, nil`    | Per-model usage breakdown.                    |
| `structured_output` | `Object, nil`  | Structured output (if requested via options). |
| `num_turns`         | `Integer, nil` | Number of turns in the session.               |

```ruby
turn = conversation.say("What is 2+2?")
puts "Model: #{turn.model}"
puts "Cost: $#{turn.cost}"
puts "Duration: #{turn.duration_ms}ms"
puts "Session: #{turn.session_id}"
```

### Status

| Method               | Return Type                  | Description                                                  |
|----------------------|------------------------------|--------------------------------------------------------------|
| `complete?`          | `Boolean`                    | Whether a `ResultMessage` has been received.                 |
| `success?`           | `Boolean`                    | Whether the turn completed successfully.                     |
| `error?`             | `Boolean`                    | Whether the turn ended with an error.                        |
| `subtype`            | `String, nil`                | The result subtype (e.g., `"success"`, `"error_max_turns"`). |
| `errors`             | `Array<String>`              | Errors from the result.                                      |
| `permission_denials` | `Array<SDKPermissionDenial>` | Tools that were denied by permission callbacks.              |

```ruby
turn = conversation.say("Deploy to production")
if turn.success?
  puts "Deployed successfully"
elsif turn.error?
  puts "Errors: #{turn.errors.join(", ")}"
end
```

### Filtered Message Access

| Method               | Return Type                                          | Description                                                           |
|----------------------|------------------------------------------------------|-----------------------------------------------------------------------|
| `messages`           | `Array<Message>`                                     | All messages received during this turn.                               |
| `assistant_messages` | `Array<AssistantMessage>`                            | Only assistant messages.                                              |
| `user_messages`      | `Array<UserMessage, UserMessageReplay>`              | Only user messages (including system-generated tool result messages). |
| `stream_events`      | `Array<StreamEvent>`                                 | Only stream events.                                                   |
| `content_blocks`     | `Array<TextBlock, ThinkingBlock, ToolUseBlock, ...>` | All content blocks across all assistant messages.                     |

## Callbacks

Register callbacks when creating the conversation to react to events as they happen. Callbacks persist across turns.

| Callback           | Arguments                        | Description                                                                                             |
|--------------------|----------------------------------|---------------------------------------------------------------------------------------------------------|
| `on_text`          | `(text)`                         | Fires when the assistant produces text content.                                                         |
| `on_stream`        | `(text)`                         | Alias for `on_text`.                                                                                    |
| `on_thinking`      | `(thinking)`                     | Fires when the assistant produces thinking content.                                                     |
| `on_tool_use`      | `(tool_use)`                     | Fires when the assistant requests a tool use. The argument is a `ToolUseBlock` or `ServerToolUseBlock`. |
| `on_tool_result`   | `(tool_result, tool_use)`        | Fires when a tool result is received. The second argument is the matched `ToolUseBlock` (or `nil`).     |
| `on_result`        | `(result)`                       | Fires when the turn completes. The argument is a `ResultMessage`.                                       |
| `on_message`       | `(message)`                      | Fires for every message (catch-all).                                                                    |
| `on_stream_event`  | `(stream_event)`                 | Fires for raw stream events.                                                                            |
| `on_status`        | `(status_message)`               | Fires for status messages (e.g., compacting).                                                           |
| `on_tool_progress` | `(tool_progress_message)`        | Fires for tool progress updates.                                                                        |
| `on_permission`    | `Symbol, Proc, PermissionPolicy` | Controls permission handling. See below.                                                                |

```ruby
conversation = ClaudeAgent::Conversation.new(
  on_text:        ->(text) { print text },
  on_thinking:    ->(thinking) { $stderr.puts "[thinking] #{thinking}" },
  on_tool_use:    ->(tool) { puts "\nUsing tool: #{tool.display_label}" },
  on_tool_result: ->(result, _tool_use) { puts "  Result: #{result.content.to_s.slice(0, 60)}" },
  on_result:      ->(r) { puts "\nCost: $#{r.total_cost_usd}" },
  on_message:     ->(msg) { $stderr.puts "[#{msg.type}]" }
)
```

### Permission Handling

The `on_permission` parameter controls how tool permission requests are handled:

- **`:queue`** (default) -- Permission requests are queued. Poll with `conversation.pending_permission`.
- **`:default`**, **`:accept_edits`**, **`:plan`**, **`:bypass_permissions`**, **`:dont_ask`** -- Maps to CLI permission modes.
- **A callable** (Proc/Lambda) -- Used as `can_use_tool` callback.
- **A `PermissionPolicy`** -- Compiled to a `can_use_tool` callback.

```ruby
# Queue mode (default) -- poll for permissions
conversation = ClaudeAgent::Conversation.new
# ... in a UI loop:
if request = conversation.pending_permission
  show_dialog(request)
end

# Callable mode
conversation = ClaudeAgent::Conversation.new(
  on_permission: ->(name, input, context) {
    ClaudeAgent::PermissionResultAllow.new
  }
)

# Symbol mode
conversation = ClaudeAgent::Conversation.new(on_permission: :accept_edits)
```

## Tool Activity Timeline

After each turn, the conversation builds `ToolActivity` entries from tool use/result pairs. These form a unified timeline across all turns with timing information.

```ruby
ClaudeAgent::Conversation.open(max_turns: 10) do |c|
  c.say("Read the config, fix the bug, and write tests")

  c.tool_activity.each do |activity|
    status = activity.error? ? "FAILED" : "OK"
    duration = activity.duration ? "#{activity.duration.round(2)}s" : "n/a"
    puts "#{activity.display_label} [#{status}] (#{duration}) -- turn #{activity.turn_index}"
  end
end
```

### ToolActivity Accessors

Each `ToolActivity` is an immutable `Data.define` object built after a turn completes.

| Method          | Return Type            | Description                                                   |
|-----------------|------------------------|---------------------------------------------------------------|
| `name`          | `String`               | Tool name (e.g., `"Read"`, `"Write"`, `"Bash"`).              |
| `display_label` | `String`               | Human-readable label.                                         |
| `summary(max:)` | `String`               | Detailed summary, truncated to `max` characters (default 60). |
| `file_path`     | `String, nil`          | File path if this is a file-based tool.                       |
| `id`            | `String`               | Tool use ID.                                                  |
| `tool_use`      | `ToolUseBlock`         | The original tool use block.                                  |
| `tool_result`   | `ToolResultBlock, nil` | The matching result block (nil if not yet received).          |
| `turn_index`    | `Integer`              | Which turn this tool was used in (zero-indexed).              |
| `started_at`    | `Time, nil`            | When the tool use was detected.                               |
| `completed_at`  | `Time, nil`            | When the tool result was received.                            |
| `duration`      | `Float, nil`           | Duration in seconds (nil if timing not available).            |
| `error?`        | `Boolean`              | Whether the tool produced an error result.                    |
| `complete?`     | `Boolean`              | Whether the tool execution is complete (has a result).        |

## Live Tool Tracking

For real-time UIs that need to show tool progress as it happens (spinners, progress bars, status indicators), enable live tracking with `track_tools: true`.

```ruby
conversation = ClaudeAgent::Conversation.new(track_tools: true)
tracker = conversation.tool_tracker
```

The `ToolActivityTracker` is an `Enumerable` collection of `LiveToolActivity` entries that updates in real time as tools start, progress, and complete. It resets at the start of each call to `say`.

### Registering Tracker Callbacks

```ruby
tracker = conversation.tool_tracker

tracker.on_start do |entry|
  puts "Started: #{entry.display_label}"
end

tracker.on_progress do |entry|
  puts "  #{entry.name}: #{entry.elapsed&.round(1)}s elapsed..."
end

tracker.on_complete do |entry|
  status = entry.error? ? "FAILED" : "done"
  puts "Finished: #{entry.display_label} (#{status})"
end

# Catch-all -- fires in addition to specific callbacks
tracker.on_change do |event, entry|
  # event is :started, :completed, or :progress
  log("#{event}: #{entry.id}")
end
```

### Querying Tracker State

```ruby
tracker.running  # => Array<LiveToolActivity> currently in progress
tracker.done     # => Array<LiveToolActivity> completed successfully
tracker.errored  # => Array<LiveToolActivity> completed with errors

tracker.size     # => Integer total count
tracker.empty?   # => Boolean

tracker.find_by_id("tool_123")  # => LiveToolActivity or nil
tracker["tool_123"]             # => same as find_by_id

tracker.each { |entry| render(entry) }
```

### LiveToolActivity

Unlike `ToolActivity` (immutable, built after a turn completes), `LiveToolActivity` is mutable and tracks status changes as they happen.

| Method          | Return Type            | Description                                             |
|-----------------|------------------------|---------------------------------------------------------|
| `id`            | `String`               | Tool use ID.                                            |
| `name`          | `String`               | Tool name.                                              |
| `input`         | `Hash`                 | Tool input parameters.                                  |
| `display_label` | `String`               | Human-readable label.                                   |
| `summary(max:)` | `String`               | Detailed summary.                                       |
| `file_path`     | `String, nil`          | File path if applicable.                                |
| `tool_use`      | `ToolUseBlock`         | The tool use block.                                     |
| `tool_result`   | `ToolResultBlock, nil` | The tool result (nil while running).                    |
| `status`        | `Symbol`               | `:running`, `:done`, or `:error`.                       |
| `started_at`    | `Time`                 | When the tool started.                                  |
| `elapsed`       | `Float, nil`           | Elapsed time in seconds (updated by progress events).   |
| `running?`      | `Boolean`              | Whether the tool is currently running.                  |
| `done?`         | `Boolean`              | Whether the tool completed successfully.                |
| `error?`        | `Boolean`              | Whether the tool completed with an error.               |
| `complete?`     | `Boolean`              | Whether the tool execution is complete (done or error). |

## Conversation Accessors

These accessors are available on the `Conversation` object itself.

| Method                 | Return Type                | Description                                                |
|------------------------|----------------------------|------------------------------------------------------------|
| `turns`                | `Array<TurnResult>`        | All completed turns.                                       |
| `messages`             | `Array<Message>`           | All messages across all turns.                             |
| `tool_activity`        | `Array<ToolActivity>`      | Unified tool timeline across all turns.                    |
| `tool_tracker`         | `ToolActivityTracker, nil` | Live tool tracker (nil unless `track_tools: true`).        |
| `total_cost`           | `Float`                    | Total cost across all turns (session-cumulative from CLI). |
| `session_id`           | `String, nil`              | Session ID from the most recent turn.                      |
| `usage`                | `CumulativeUsage`          | Cumulative usage stats.                                    |
| `open?`                | `Boolean`                  | Whether the conversation is open (client connected).       |
| `closed?`              | `Boolean`                  | Whether the conversation has been closed.                  |
| `pending_permission`   | `PermissionRequest, nil`   | Next pending permission request (non-blocking poll).       |
| `pending_permissions?` | `Boolean`                  | Whether any permission requests are pending.               |

```ruby
ClaudeAgent::Conversation.open(max_turns: 10) do |c|
  c.say("Refactor the auth module")
  c.say("Now add integration tests")

  puts "Turns: #{c.turns.size}"
  puts "Messages: #{c.messages.size}"
  puts "Tools: #{c.tool_activity.size}"
  puts "Session: #{c.session_id}"
  puts "Total cost: $#{c.total_cost}"
  puts "Input tokens: #{c.usage.input_tokens}"
  puts "Output tokens: #{c.usage.output_tokens}"
end
```

## Resuming a Conversation

Resume a previous conversation by session ID. The CLI restores the conversation context from the session transcript.

### `Conversation.resume`

```ruby
conversation = ClaudeAgent::Conversation.resume("session-abc-123")
turn = conversation.say("Continue where we left off")
puts turn.text
conversation.close
```

### `ClaudeAgent.resume_conversation`

Module-level convenience that delegates to `Conversation.resume`.

```ruby
conversation = ClaudeAgent.resume_conversation("session-abc-123",
  max_turns: 5,
  on_text: ->(text) { print text }
)
turn = conversation.say("What did we discuss last time?")
conversation.close
```

Both methods accept the same keyword arguments as `Conversation.new` for callbacks and options.

## Cumulative Usage

The `CumulativeUsage` object tracks token counts, cost, and duration across all turns in a conversation.

Access it via `conversation.usage`:

```ruby
ClaudeAgent::Conversation.open do |c|
  c.say("Hello")
  c.say("Follow up question")

  usage = c.usage
  puts "Input tokens:  #{usage.input_tokens}"
  puts "Output tokens: #{usage.output_tokens}"
  puts "Cache read:    #{usage.cache_read_input_tokens}"
  puts "Cache create:  #{usage.cache_creation_input_tokens}"
  puts "Total cost:    $#{usage.total_cost_usd}"
  puts "Turns:         #{usage.num_turns}"
  puts "Duration:      #{usage.duration_ms}ms"
  puts "API duration:  #{usage.duration_api_ms}ms"
end
```

### CumulativeUsage Fields

| Field                         | Type      | Description                                                                    |
|-------------------------------|-----------|--------------------------------------------------------------------------------|
| `input_tokens`                | `Integer` | Sum of input tokens across all turns.                                          |
| `output_tokens`               | `Integer` | Sum of output tokens across all turns.                                         |
| `cache_read_input_tokens`     | `Integer` | Sum of cache-read input tokens across all turns.                               |
| `cache_creation_input_tokens` | `Integer` | Sum of cache-creation input tokens across all turns.                           |
| `total_cost_usd`              | `Float`   | Session-cumulative cost from the CLI (not summed -- replaced each turn).       |
| `num_turns`                   | `Integer` | Session-cumulative turn count from the CLI (not summed -- replaced each turn). |
| `duration_ms`                 | `Integer` | Sum of wall-clock duration across all turns.                                   |
| `duration_api_ms`             | `Integer` | Sum of API-only duration across all turns.                                     |

Token counts are summed across turns because the CLI reports per-turn values. Cost and turn count are session-cumulative values from the CLI and are replaced (not summed) on each result.
