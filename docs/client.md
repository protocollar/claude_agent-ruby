# Client

The `Client` class provides fine-grained, bidirectional control over a persistent Claude Code CLI connection. It supports multi-turn conversations, streaming, interrupts, dynamic model and permission changes, file checkpointing, and MCP server management.

> **Most users should prefer the higher-level APIs.** `ClaudeAgent.ask` handles one-shot queries with global configuration. `ClaudeAgent.chat` and `Conversation` manage multi-turn state, auto-connection, event callbacks, tool activity tracking, and cleanup. Reach for `Client` only when you need direct control over connection lifecycle, split send/receive, or protocol-level commands that `Conversation` does not expose.

## Overview

`Client` wraps a `ControlProtocol` over a `Transport::Subprocess`, giving you:

- Persistent connection with explicit connect/disconnect
- Multiple conversation turns over a single CLI process
- Streaming message delivery via enumerators or blocks
- Typed event handlers that persist across turns
- Control commands: model switching, permission changes, file rewind, MCP management
- Abort/interrupt support with partial result recovery
- Cumulative usage tracking across all turns
- Asynchronous permission queue for UI-driven approval flows

## Creating and Connecting

### Constructor

```ruby
client = ClaudeAgent::Client.new(
  options: ClaudeAgent::Options.new(model: "opus", max_turns: 10),
  transport: nil  # defaults to Transport::Subprocess
)
```

Both parameters are optional. When omitted, `options` defaults to a bare `Options.new` and `transport` defaults to a `Transport::Subprocess` built from those options.

### Connecting

Call `connect` to start the CLI subprocess and perform the protocol handshake. An optional `prompt` sends an initial message immediately after connection.

```ruby
client.connect
client.connect(prompt: "You are a helpful coding assistant")
```

Raises `CLIConnectionError` if the client is already connected.

### Block form

`Client.open` connects, yields the client, and guarantees disconnection:

```ruby
ClaudeAgent::Client.open(
  options: ClaudeAgent::Options.new(model: "opus"),
  prompt: "Hello"
) do |client|
  client.send_message("Fix the bug")
  client.receive_response.each { |msg| puts msg }
end
# client is automatically disconnected here
```

## Sending and Receiving

### send_and_receive

The primary method for a complete turn. Sends a message and blocks until a `ResultMessage` arrives, accumulating everything into a `TurnResult`. Dispatches registered event handlers as messages flow through.

```ruby
turn = client.send_and_receive("Fix the bug in auth.rb")
puts turn.text
puts "Cost: $#{turn.cost}"
puts "Tools used: #{turn.tool_uses.map(&:display_label).join(", ")}"
```

With a streaming block:

```ruby
turn = client.send_and_receive("Fix the bug") do |msg|
  case msg
  when ClaudeAgent::AssistantMessage
    print msg.text
  end
end
```

Parameters:

| Parameter     | Type              | Default     | Description                          |
|---------------|-------------------|-------------|--------------------------------------|
| `content`     | `String`, `Array` | required    | Message content                      |
| `session_id:` | `String`          | `"default"` | Session ID for multi-session support |
| `uuid:`       | `String`, `nil`   | `nil`       | Message UUID for file checkpointing  |

Returns a `TurnResult`. See the [Queries](queries.md) doc for `TurnResult` accessors.

### Split send/receive

For finer control, separate the send and receive steps.

**send_message** queues a message to the CLI without waiting for a response:

```ruby
client.send_message("Hello")
client.send_message("Follow up", session_id: "session-2", uuid: "msg-uuid-1")
```

**query** is an alias for `send_message`:

```ruby
client.query("Hello")
```

**receive_turn** blocks until a `ResultMessage` arrives, returning a `TurnResult`. It dispatches event handlers and resets turn-level handler state afterward.

```ruby
client.send_message("Fix the bug")
turn = client.receive_turn
puts turn.text
```

With a block:

```ruby
turn = client.receive_turn do |msg|
  print msg.text if msg.is_a?(ClaudeAgent::AssistantMessage)
end
```

**receive_response** returns an `Enumerator` of messages for the current turn (until a `ResultMessage`). No event dispatch or `TurnResult` accumulation -- you process each message yourself.

```ruby
client.send_message("Hello")
client.receive_response.each do |msg|
  case msg
  when ClaudeAgent::AssistantMessage
    print msg.text
  when ClaudeAgent::ResultMessage
    puts "\nDone: #{msg.total_cost_usd}"
  end
end
```

**receive_messages** returns an `Enumerator` over all messages until the connection closes (not just one turn):

```ruby
client.receive_messages.each { |msg| handle(msg) }
```

## Event Handlers

Register typed callbacks that fire automatically during `receive_turn` and `send_and_receive`. Handlers persist across turns -- register once, and they fire on every subsequent turn.

### Registering handlers

Use `on` with a symbol, or the `on_*` convenience methods:

```ruby
client.on(:text) { |text| print text }
client.on(:tool_use) { |tool| puts "Using: #{tool.display_label}" }
client.on(:result) { |result| puts "Cost: $#{result.total_cost_usd}" }

# Equivalent convenience methods:
client.on_text { |text| print text }
client.on_tool_use { |tool| puts "Using: #{tool.display_label}" }
client.on_result { |result| puts "Cost: $#{result.total_cost_usd}" }
```

### Chaining

All registration methods return `self`, so they chain:

```ruby
client
  .on(:text) { |text| print text }
  .on(:tool_use) { |tool| show_spinner(tool) }
  .on(:result) { |r| puts "\nDone!" }
```

### Event hierarchy

Events fire in three layers for each message:

1. **Catch-all** -- `:message` fires for every message
2. **Type-based** -- the message's type fires (e.g., `:assistant`, `:stream_event`, `:status`)
3. **Decomposed** -- convenience events extracted from rich content types

**Decomposed events:**

| Event          | Argument                                   | Source                                                       |
|----------------|--------------------------------------------|--------------------------------------------------------------|
| `:text`        | `String`                                   | Text from `AssistantMessage`                                 |
| `:thinking`    | `String`                                   | Thinking from `AssistantMessage`                             |
| `:tool_use`    | `ToolUseBlock` or `ServerToolUseBlock`     | Tool call from `AssistantMessage`                            |
| `:tool_result` | `ToolResultBlock`, `ToolUseBlock` or `nil` | Tool result from `UserMessage`, paired with original request |

**Type-based events:**

`:user`, `:assistant`, `:system`, `:result`, `:stream_event`, `:compact_boundary`, `:status`, `:tool_progress`, `:hook_response`, `:auth_status`, `:task_notification`, `:hook_started`, `:hook_progress`, `:tool_use_summary`, `:task_started`, `:task_progress`, `:rate_limit_event`, `:prompt_suggestion`, `:files_persisted`, `:elicitation_complete`, `:local_command_output`

## Control Methods

These methods send control commands to the running CLI process. All require an active connection.

### set_model

Change the model for subsequent turns:

```ruby
client.set_model("claude-sonnet-4-5-20250514")
client.set_model(nil)  # revert to default
```

### set_permission_mode

Change the permission mode:

```ruby
client.set_permission_mode("acceptEdits")
```

### set_max_thinking_tokens

Set or reset the maximum thinking tokens:

```ruby
client.set_max_thinking_tokens(10_000)
client.set_max_thinking_tokens(nil)  # reset to default
```

### stop_task

Stop a running background task by its ID (from `task_notification` events):

```ruby
client.stop_task("task-123")
```

### apply_flag_settings

Merge settings into the flag settings layer:

```ruby
client.apply_flag_settings({ "model" => "claude-sonnet-4-5-20250514" })
```

## File Checkpointing

When `enable_file_checkpointing: true` is set in Options and UUIDs are passed with messages, you can rewind files to the state at a specific user message.

### rewind_files

```ruby
result = client.rewind_files("user-message-uuid")
result.can_rewind      # => true
result.files_changed   # => ["src/foo.rb", "src/bar.rb"]
result.insertions      # => 10
result.deletions       # => 5
result.error           # => nil
```

Dry-run mode previews changes without modifying files:

```ruby
result = client.rewind_files("user-message-uuid", dry_run: true)
```

Returns a `RewindFilesResult` with fields: `can_rewind`, `error`, `files_changed`, `insertions`, `deletions`.

## Dynamic MCP Management

Manage MCP (Model Context Protocol) servers on a live connection without restarting.

### set_mcp_servers

Replace the set of dynamically-added MCP servers. New servers are connected; removed servers are disconnected.

```ruby
result = client.set_mcp_servers({
  "my-server" => { type: "stdio", command: "node", args: ["server.js"] }
})
result.added    # => ["my-server"]
result.removed  # => ["old-server"]
result.errors   # => {} or {"server2" => "Connection failed"}
```

Returns a `McpSetServersResult` with fields: `added`, `removed`, `errors`.

### mcp_reconnect

Reconnect to a disconnected or errored MCP server:

```ruby
client.mcp_reconnect("my-server")
```

### mcp_toggle

Enable or disable a server without removing its configuration:

```ruby
client.mcp_toggle("my-server", enabled: false)
client.mcp_toggle("my-server", enabled: true)
```

### mcp_authenticate

Initiate OAuth authentication for a remote MCP server:

```ruby
client.mcp_authenticate("my-remote-server")
```

### mcp_clear_auth

Clear stored authentication credentials for an MCP server:

```ruby
client.mcp_clear_auth("my-remote-server")
```

## Query Capabilities

Query the CLI for available resources.

### supported_commands

```ruby
commands = client.supported_commands
# => [#<SlashCommand name="commit" description="Create a commit" argument_hint="[message]">, ...]
```

Returns `Array<SlashCommand>`.

### supported_models

```ruby
models = client.supported_models
models.each { |m| puts "#{m.value}: #{m.display_name}" }
```

Returns `Array<ModelInfo>`.

### supported_agents

```ruby
agents = client.supported_agents
agents.each { |a| puts "#{a.name}: #{a.description}" }
```

Returns `Array<AgentInfo>`.

### mcp_server_status

```ruby
statuses = client.mcp_server_status
statuses.each { |s| puts "#{s.name}: #{s.status}" }
```

Returns `Array<McpServerStatus>`. Status values: `"connected"`, `"failed"`, `"needs-auth"`, `"pending"`.

### account_info

```ruby
info = client.account_info
puts "#{info.email} (#{info.organization})"
```

Returns an `AccountInfo` with fields: `email`, `organization`, `subscription_type`, `token_source`, `api_key_source`.

## Permission Queue

When `permission_queue: true` is set in Options (or `can_use_tool` defers a request), the CLI routes tool permission prompts through a thread-safe queue instead of requiring synchronous callback resolution. This is useful for UI-driven applications where a separate thread or event loop handles approval dialogs.

### pending_permission

Non-blocking poll for the next pending request. Returns `nil` if the queue is empty.

```ruby
if request = client.pending_permission
  puts "Tool: #{request.tool_name}"
  puts "Input: #{request.input}"
  puts "Label: #{request.display_label}"

  request.allow!
  # or: request.deny!(message: "Not allowed in production")
end
```

### pending_permissions?

Check whether any requests are waiting:

```ruby
client.pending_permissions?  # => true/false
```

### permission_queue

Direct access to the underlying `PermissionQueue` for blocking waits or batch draining:

```ruby
# Blocking wait (with optional timeout)
request = client.permission_queue.pop(timeout: 30)

# Drain all pending (used during cleanup)
client.permission_queue.drain!(reason: "Shutting down")
```

`PermissionRequest` methods:

| Method                                         | Description                                                     |
|------------------------------------------------|-----------------------------------------------------------------|
| `allow!(updated_input:, updated_permissions:)` | Allow execution, optionally modifying input or permission rules |
| `deny!(message:, interrupt:)`                  | Deny execution with a reason; optionally interrupt the agent    |
| `tool_name`                                    | Name of the tool requesting permission                          |
| `input`                                        | Tool input hash                                                 |
| `display_label`                                | Human-readable label (e.g., `"Read(path: /tmp/file.txt)"`)      |
| `summary(max:)`                                | Detailed summary, truncated to `max` characters                 |
| `pending?` / `resolved?`                       | Resolution state                                                |
| `created_at`                                   | Timestamp of the request                                        |

## Cumulative Usage

The client tracks token usage, cost, and timing across all turns.

```ruby
usage = client.cumulative_usage
puts "Input tokens:  #{usage.input_tokens}"
puts "Output tokens: #{usage.output_tokens}"
puts "Cache read:    #{usage.cache_read_input_tokens}"
puts "Cache created: #{usage.cache_creation_input_tokens}"
puts "Total cost:    $#{usage.total_cost_usd}"
puts "Turns:         #{usage.num_turns}"
puts "Duration:      #{usage.duration_ms}ms"
puts "API duration:  #{usage.duration_api_ms}ms"
```

Returns a `CumulativeUsage` instance. Token counts are summed across turns. Cost and turn count reflect session-cumulative values from the CLI.

## Streaming Input

Send multiple messages from an enumerable source.

### Without block (send only)

```ruby
client.stream_input(["Hello", "How are you?"])
client.receive_response.each { |msg| puts msg }
```

### With block (concurrent send/receive)

Messages are sent in a background thread while responses are yielded to the block:

```ruby
client.stream_input(["Hello", "Follow up"], session_id: "default") do |msg|
  case msg
  when ClaudeAgent::AssistantMessage
    puts msg.text
  when ClaudeAgent::ResultMessage
    puts "Done!"
  end
end
```

## Abort and Interrupt

### interrupt

Send an interrupt signal to the CLI, stopping the current generation:

```ruby
client.interrupt
```

### abort!

Abort all pending operations. Triggers the abort controller (if configured), drains the permission queue, and terminates the transport.

```ruby
client.abort!
client.abort!("User cancelled")
```

### AbortController

For cross-thread cancellation, configure an `AbortController` on Options:

```ruby
controller = ClaudeAgent::AbortController.new

options = ClaudeAgent::Options.new(abort_controller: controller)
client = ClaudeAgent::Client.new(options: options)
client.connect

# In another thread:
Thread.new { sleep(5); controller.abort("Timeout") }

begin
  turn = client.send_and_receive("Long running task")
rescue ClaudeAgent::AbortError => e
  partial = e.partial_turn
  puts partial.text         # text accumulated before abort
  puts partial.tool_uses    # tools that ran before abort
end
```

The `AbortSignal` is thread-safe and supports callbacks:

```ruby
controller.signal.on_abort { |reason| puts "Aborted: #{reason}" }
controller.signal.aborted?  # => false
controller.abort("Done")
controller.signal.aborted?  # => true
controller.signal.reason    # => "Done"
```

Call `controller.reset!` to reuse the controller for another turn. `Conversation` does this automatically.

## Disconnect

```ruby
client.disconnect
client.connected?  # => false
```

Disconnecting drains the permission queue (denying all pending requests with "Client disconnected"), stops the protocol, and terminates the CLI subprocess. Calling `disconnect` on an already-disconnected client is a no-op.

`Client.open` calls `disconnect` automatically in its `ensure` block.
