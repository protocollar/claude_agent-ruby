# Messages & Content Blocks Reference

Complete reference for all message types and content blocks in the ClaudeAgent Ruby SDK.

All types are immutable (`Data.define`, frozen at construction). All types include the `ClaudeAgent::Message` module.

## Message Module

Every message and content block type includes `ClaudeAgent::Message`, which provides:

| Method             | Returns   | Description                                                                                            |
|--------------------|-----------|--------------------------------------------------------------------------------------------------------|
| `text_content`     | `String`  | Universal text extraction. Works on any message or block type. Returns `""` when no text is available. |
| `session_message?` | `Boolean` | `true` if the message has non-nil `uuid` and `session_id`.                                             |
| `identifiable?`    | `Boolean` | `true` if the message has a non-nil `uuid`.                                                            |
| `deconstruct_keys` | `Hash`    | Injects `:type` as a virtual key for pattern matching.                                                 |

### text_content behavior by type

| Type                               | Extracts from                                       |
|------------------------------------|-----------------------------------------------------|
| `AssistantMessage`                 | Concatenated `TextBlock` text via `#text`           |
| `UserMessage`, `UserMessageReplay` | `content` if it is a `String`                       |
| `TextBlock`                        | `text`                                              |
| `ThinkingBlock`                    | `thinking`                                          |
| `StreamEvent`                      | `delta_text`                                        |
| `GenericMessage`                   | `raw[:text]` or `raw["text"]`                       |
| Everything else                    | `text` if the object responds to it, otherwise `""` |

## Pattern Matching

The `Message` module overrides `deconstruct_keys` to inject a `:type` virtual key, enabling Ruby pattern matching on message types:

```ruby
case message
in { type: :assistant }
  puts message.text_content
in { type: :result, is_error: true }
  warn "Error: #{message.errors}"
in { type: :result }
  puts "Cost: $#{message.total_cost_usd}"
in { type: :system, subtype: "init" }
  puts "Session initialized"
in { type: :stream_event }
  print message.delta_text
end
```

You can also combine pattern matching with field extraction:

```ruby
case message
in { type: :assistant, model: }
  puts "Model: #{model}"
in { type: :hook_response, outcome: "error", stderr: }
  warn stderr
end
```

---

## Message Types

24 message types, grouped by category.

### Conversation Messages

#### UserMessage

User message sent to Claude.

```ruby
UserMessage = Data.define(:content, :uuid, :session_id, :parent_tool_use_id)
```

| Field                | Type                | Default  |
|----------------------|---------------------|----------|
| `content`            | `String` or `Array` | required |
| `uuid`               | `String, nil`       | `nil`    |
| `session_id`         | `String, nil`       | `nil`    |
| `parent_tool_use_id` | `String, nil`       | `nil`    |

Methods:

- `type` -- `:user`
- `text` -- returns `content` if it is a `String`, else `nil`
- `replay?` -- always `false`

#### UserMessageReplay

Replayed user message from a resumed session.

```ruby
UserMessageReplay = Data.define(
  :content, :uuid, :session_id, :parent_tool_use_id,
  :is_replay, :is_synthetic, :tool_use_result
)
```

| Field                | Type                | Default  |
|----------------------|---------------------|----------|
| `content`            | `String` or `Array` | required |
| `uuid`               | `String, nil`       | `nil`    |
| `session_id`         | `String, nil`       | `nil`    |
| `parent_tool_use_id` | `String, nil`       | `nil`    |
| `is_replay`          | `Boolean`           | `true`   |
| `is_synthetic`       | `Boolean, nil`      | `nil`    |
| `tool_use_result`    | `Hash, nil`         | `nil`    |

Methods:

- `type` -- `:user`
- `text` -- returns `content` if it is a `String`, else `nil`
- `replay?` -- `true` if `is_replay == true`
- `synthetic?` -- `true` if `is_synthetic == true`

#### AssistantMessage

Response from Claude containing content blocks.

```ruby
AssistantMessage = Data.define(:content, :model, :uuid, :session_id, :error, :parent_tool_use_id)
```

| Field                | Type                  | Default  |
|----------------------|-----------------------|----------|
| `content`            | `Array<ContentBlock>` | required |
| `model`              | `String`              | required |
| `uuid`               | `String, nil`         | `nil`    |
| `session_id`         | `String, nil`         | `nil`    |
| `error`              | `Hash, nil`           | `nil`    |
| `parent_tool_use_id` | `String, nil`         | `nil`    |

Methods:

- `type` -- `:assistant`
- `text` -- concatenated text from all `TextBlock`s
- `thinking` -- concatenated text from all `ThinkingBlock`s
- `tool_uses` -- `Array<ToolUseBlock>` from content
- `has_tool_use?` -- `true` if any content block is a `ToolUseBlock`

```ruby
msg.text           # => "Hello, world!"
msg.tool_uses      # => [#<ToolUseBlock id="tool_1" name="Read" ...>]
msg.has_tool_use?  # => true
```

### Result

#### ResultMessage

Final message with cost, usage, and outcome info.

```ruby
ResultMessage = Data.define(
  :subtype, :duration_ms, :duration_api_ms, :is_error, :num_turns,
  :session_id, :uuid, :total_cost_usd, :usage, :result, :structured_output,
  :errors, :permission_denials, :model_usage, :stop_reason, :fast_mode_state
)
```

| Field                | Type                 | Default  |
|----------------------|----------------------|----------|
| `subtype`            | `String`             | required |
| `duration_ms`        | `Integer`            | required |
| `duration_api_ms`    | `Integer`            | required |
| `is_error`           | `Boolean`            | required |
| `num_turns`          | `Integer`            | required |
| `session_id`         | `String`             | required |
| `uuid`               | `String, nil`        | `nil`    |
| `total_cost_usd`     | `Float, nil`         | `nil`    |
| `usage`              | `Hash, nil`          | `nil`    |
| `result`             | `String, nil`        | `nil`    |
| `structured_output`  | `Hash, nil`          | `nil`    |
| `errors`             | `Array<String>, nil` | `nil`    |
| `permission_denials` | `Array, nil`         | `nil`    |
| `model_usage`        | `Hash, nil`          | `nil`    |
| `stop_reason`        | `String, nil`        | `nil`    |
| `fast_mode_state`    | `Hash, nil`          | `nil`    |

Methods:

- `type` -- `:result`
- `error?` -- `true` if `is_error`
- `success?` -- `true` if not `is_error`

### System & Status

#### SystemMessage

Internal system event (e.g., session init).

```ruby
SystemMessage = Data.define(:subtype, :data)
```

| Field     | Type     | Default  |
|-----------|----------|----------|
| `subtype` | `String` | required |
| `data`    | `Hash`   | required |

Methods:

- `type` -- `:system`

#### CompactBoundaryMessage

Conversation compaction marker.

```ruby
CompactBoundaryMessage = Data.define(:uuid, :session_id, :compact_metadata)
```

| Field              | Type     | Default  |
|--------------------|----------|----------|
| `uuid`             | `String` | required |
| `session_id`       | `String` | required |
| `compact_metadata` | `Hash`   | required |

Methods:

- `type` -- `:compact_boundary`
- `trigger` -- compaction trigger type (`"manual"` or `"auto"`)
- `pre_tokens` -- token count before compaction

#### APIRetryMessage

Emitted when an API request fails with a retryable error and will be retried.

```ruby
APIRetryMessage = Data.define(:uuid, :session_id, :attempt, :max_retries, :retry_delay_ms, :error_status, :error)
```

| Field            | Type           | Default |
|------------------|----------------|---------|
| `uuid`           | `String`       | `""`    |
| `session_id`     | `String`       | `""`    |
| `attempt`        | `Integer`      | `0`     |
| `max_retries`    | `Integer`      | `0`     |
| `retry_delay_ms` | `Integer`      | `0`     |
| `error_status`   | `Integer, nil` | `nil`   |
| `error`          | `String, nil`  | `nil`   |

Methods:

- `type` -- `:api_retry`

#### StatusMessage

Session status report (e.g., `"compacting"`).

```ruby
StatusMessage = Data.define(:uuid, :session_id, :status, :permission_mode)
```

| Field             | Type          | Default  |
|-------------------|---------------|----------|
| `uuid`            | `String`      | required |
| `session_id`      | `String`      | required |
| `status`          | `String`      | required |
| `permission_mode` | `String, nil` | `nil`    |

Methods:

- `type` -- `:status`

### Streaming

#### StreamEvent

Partial message during streaming.

```ruby
StreamEvent = Data.define(:uuid, :session_id, :event, :parent_tool_use_id)
```

| Field                | Type          | Default  |
|----------------------|---------------|----------|
| `uuid`               | `String`      | required |
| `session_id`         | `String`      | required |
| `event`              | `Hash`        | required |
| `parent_tool_use_id` | `String, nil` | `nil`    |

Methods:

- `type` -- `:stream_event`
- `event_type` -- raw event type string (e.g., `"content_block_delta"`)
- `delta_text` -- text delta content, or `nil` if not a text delta
- `delta_type` -- delta type string (e.g., `"text_delta"`, `"thinking_delta"`)
- `thinking_text` -- thinking delta text, or `nil` if not a thinking delta
- `content_index` -- content block index within the message

```ruby
event.delta_text     # => "Hello"
event.delta_type     # => "text_delta"
event.thinking_text  # => nil (only set for thinking deltas)
```

#### RateLimitEvent

Rate limit status and utilization info.

```ruby
RateLimitEvent = Data.define(:rate_limit_info, :uuid, :session_id)
```

| Field             | Type          | Default  |
|-------------------|---------------|----------|
| `rate_limit_info` | `Hash`        | required |
| `uuid`            | `String, nil` | `nil`    |
| `session_id`      | `String, nil` | `nil`    |

Methods:

- `type` -- `:rate_limit_event`
- `status` -- rate limit status string (e.g., `"allowed_warning"`)

#### PromptSuggestionMessage

Suggested prompt for the user.

```ruby
PromptSuggestionMessage = Data.define(:uuid, :session_id, :suggestion)
```

| Field        | Type          | Default  |
|--------------|---------------|----------|
| `uuid`       | `String, nil` | `nil`    |
| `session_id` | `String, nil` | `nil`    |
| `suggestion` | `String`      | required |

Methods:

- `type` -- `:prompt_suggestion`

### Tool Lifecycle

#### ToolProgressMessage

Progress during long-running tool execution.

```ruby
ToolProgressMessage = Data.define(
  :uuid, :session_id, :tool_use_id, :tool_name,
  :parent_tool_use_id, :elapsed_time_seconds, :task_id
)
```

| Field                  | Type          | Default  |
|------------------------|---------------|----------|
| `uuid`                 | `String`      | required |
| `session_id`           | `String`      | required |
| `tool_use_id`          | `String`      | required |
| `tool_name`            | `String`      | required |
| `elapsed_time_seconds` | `Float`       | required |
| `parent_tool_use_id`   | `String, nil` | `nil`    |
| `task_id`              | `String, nil` | `nil`    |

Methods:

- `type` -- `:tool_progress`

#### ToolUseSummaryMessage

Summary of tool use for collapsed display.

```ruby
ToolUseSummaryMessage = Data.define(:uuid, :session_id, :summary, :preceding_tool_use_ids)
```

| Field                    | Type            | Default  |
|--------------------------|-----------------|----------|
| `uuid`                   | `String`        | required |
| `session_id`             | `String`        | required |
| `summary`                | `String`        | required |
| `preceding_tool_use_ids` | `Array<String>` | `[]`     |

Methods:

- `type` -- `:tool_use_summary`

#### LocalCommandOutputMessage

Output from a local command execution.

```ruby
LocalCommandOutputMessage = Data.define(:uuid, :session_id, :content)
```

| Field        | Type     | Default |
|--------------|----------|---------|
| `uuid`       | `String` | `""`    |
| `session_id` | `String` | `""`    |
| `content`    | `String` | `""`    |

Methods:

- `type` -- `:local_command_output`

### Hook Lifecycle

#### HookStartedMessage

Sent when a hook execution starts.

```ruby
HookStartedMessage = Data.define(:uuid, :session_id, :hook_id, :hook_name, :hook_event)
```

| Field        | Type     | Default  |
|--------------|----------|----------|
| `uuid`       | `String` | required |
| `session_id` | `String` | required |
| `hook_id`    | `String` | required |
| `hook_name`  | `String` | required |
| `hook_event` | `String` | required |

Methods:

- `type` -- `:hook_started`

#### HookProgressMessage

Progress during hook execution.

```ruby
HookProgressMessage = Data.define(
  :uuid, :session_id, :hook_id, :hook_name, :hook_event,
  :stdout, :stderr, :output
)
```

| Field        | Type     | Default  |
|--------------|----------|----------|
| `uuid`       | `String` | required |
| `session_id` | `String` | required |
| `hook_id`    | `String` | required |
| `hook_name`  | `String` | required |
| `hook_event` | `String` | required |
| `stdout`     | `String` | `""`     |
| `stderr`     | `String` | `""`     |
| `output`     | `String` | `""`     |

Methods:

- `type` -- `:hook_progress`

#### HookResponseMessage

Final result of a hook execution.

```ruby
HookResponseMessage = Data.define(
  :uuid, :session_id, :hook_id, :hook_name, :hook_event,
  :stdout, :stderr, :output, :exit_code, :outcome
)
```

| Field        | Type           | Default  |
|--------------|----------------|----------|
| `uuid`       | `String`       | required |
| `session_id` | `String`       | required |
| `hook_id`    | `String, nil`  | `nil`    |
| `hook_name`  | `String`       | required |
| `hook_event` | `String`       | required |
| `stdout`     | `String`       | `""`     |
| `stderr`     | `String`       | `""`     |
| `output`     | `String`       | `""`     |
| `exit_code`  | `Integer, nil` | `nil`    |
| `outcome`    | `String, nil`  | `nil`    |

Methods:

- `type` -- `:hook_response`
- `success?` -- `true` if `outcome == "success"`
- `error?` -- `true` if `outcome == "error"`
- `cancelled?` -- `true` if `outcome == "cancelled"`

### Task Lifecycle

#### TaskStartedMessage

Sent when a new task (subagent) starts.

```ruby
TaskStartedMessage = Data.define(
  :uuid, :session_id, :task_id, :tool_use_id,
  :description, :task_type, :prompt
)
```

| Field         | Type          | Default  |
|---------------|---------------|----------|
| `uuid`        | `String`      | required |
| `session_id`  | `String`      | required |
| `task_id`     | `String`      | required |
| `tool_use_id` | `String, nil` | `nil`    |
| `description` | `String, nil` | `nil`    |
| `task_type`   | `String, nil` | `nil`    |
| `prompt`      | `String, nil` | `nil`    |

Methods:

- `type` -- `:task_started`

#### TaskProgressMessage

Progress during background task (subagent) execution.

```ruby
TaskProgressMessage = Data.define(
  :uuid, :session_id, :task_id, :tool_use_id,
  :description, :usage, :last_tool_name, :summary
)
```

| Field            | Type          | Default  |
|------------------|---------------|----------|
| `uuid`           | `String`      | required |
| `session_id`     | `String`      | required |
| `task_id`        | `String`      | required |
| `description`    | `String`      | required |
| `tool_use_id`    | `String, nil` | `nil`    |
| `usage`          | `Hash, nil`   | `nil`    |
| `last_tool_name` | `String, nil` | `nil`    |
| `summary`        | `String, nil` | `nil`    |

Methods:

- `type` -- `:task_progress`

#### TaskNotificationMessage

Sent when a background task completes, fails, or is stopped.

```ruby
TaskNotificationMessage = Data.define(
  :uuid, :session_id, :task_id, :status,
  :output_file, :summary, :tool_use_id, :usage
)
```

| Field         | Type          | Default  |
|---------------|---------------|----------|
| `uuid`        | `String`      | required |
| `session_id`  | `String`      | required |
| `task_id`     | `String`      | required |
| `status`      | `String`      | required |
| `output_file` | `String`      | required |
| `summary`     | `String`      | required |
| `tool_use_id` | `String, nil` | `nil`    |
| `usage`       | `Hash, nil`   | `nil`    |

Methods:

- `type` -- `:task_notification`
- `completed?` -- `true` if `status == "completed"`
- `failed?` -- `true` if `status == "failed"`
- `stopped?` -- `true` if `status == "stopped"`

### Other

#### FilesPersistedEvent

Sent when files are persisted to storage.

```ruby
FilesPersistedEvent = Data.define(:uuid, :session_id, :files, :failed, :processed_at)
```

| Field          | Type          | Default  |
|----------------|---------------|----------|
| `uuid`         | `String`      | required |
| `session_id`   | `String`      | required |
| `files`        | `Array<Hash>` | `[]`     |
| `failed`       | `Array<Hash>` | `[]`     |
| `processed_at` | `String, nil` | `nil`    |

Methods:

- `type` -- `:files_persisted`

#### ElicitationCompleteMessage

Sent when an MCP server elicitation request completes.

```ruby
ElicitationCompleteMessage = Data.define(:uuid, :session_id, :mcp_server_name, :elicitation_id)
```

| Field             | Type     | Default |
|-------------------|----------|---------|
| `uuid`            | `String` | `""`    |
| `session_id`      | `String` | `""`    |
| `mcp_server_name` | `String` | `""`    |
| `elicitation_id`  | `String` | `""`    |

Methods:

- `type` -- `:elicitation_complete`

#### AuthStatusMessage

Authentication status during login flows.

```ruby
AuthStatusMessage = Data.define(:uuid, :session_id, :is_authenticating, :output, :error)
```

| Field               | Type          | Default  |
|---------------------|---------------|----------|
| `uuid`              | `String`      | required |
| `session_id`        | `String`      | required |
| `is_authenticating` | `Boolean`     | required |
| `output`            | `Array`       | `[]`     |
| `error`             | `String, nil` | `nil`    |

Methods:

- `type` -- `:auth_status`

#### GenericMessage

Catch-all for unknown/future protocol message types. Supports dynamic field access.

```ruby
GenericMessage = Data.define(:message_type, :raw)
```

| Field          | Type     | Default  |
|----------------|----------|----------|
| `message_type` | `String` | required |
| `raw`          | `Hash`   | required |

Methods:

- `type` -- `message_type` as a symbol, or `:unknown`
- `to_h` -- returns `raw`
- `[](key)` -- hash-style access into `raw`
- `method_missing` -- dynamic field access into `raw`

```ruby
msg = GenericMessage.new(message_type: "fancy_new", raw: { data: "hello" })
msg.type    # => :fancy_new
msg[:data]  # => "hello"
msg.data    # => "hello"
```

---

## Content Blocks

8 content block types. Found inside `AssistantMessage#content` arrays.

### TextBlock

Plain text content.

```ruby
TextBlock = Data.define(:text)
```

| Field  | Type     | Default  |
|--------|----------|----------|
| `text` | `String` | required |

Methods:

- `type` -- `:text`
- `to_h` -- `{ type: "text", text: text }`

### ThinkingBlock

Extended thinking content.

```ruby
ThinkingBlock = Data.define(:thinking, :signature)
```

| Field       | Type     | Default  |
|-------------|----------|----------|
| `thinking`  | `String` | required |
| `signature` | `String` | required |

Methods:

- `type` -- `:thinking`
- `to_h` -- `{ type: "thinking", thinking: thinking, signature: signature }`

### ToolUseBlock

Tool use request from Claude.

```ruby
ToolUseBlock = Data.define(:id, :name, :input)
```

| Field   | Type     | Default  |
|---------|----------|----------|
| `id`    | `String` | required |
| `name`  | `String` | required |
| `input` | `Hash`   | required |

Methods:

- `type` -- `:tool_use`
- `file_path` -- file path for file-based tools (`Read`, `Write`, `Edit`, `NotebookEdit`), else `nil`
- `display_label` -- one-line human-readable label (e.g., `"Read config/app.rb"`, `"Bash: ls -la"`)
- `summary(max: 60)` -- detailed summary, truncated to `max` characters
- `to_h` -- `{ type: "tool_use", id: id, name: name, input: input }`

```ruby
block = ToolUseBlock.new(id: "tool_1", name: "Read", input: { file_path: "/tmp/file.rb" })
block.file_path      # => "/tmp/file.rb"
block.display_label  # => "Read file.rb"
block.summary        # => "Read: /tmp/file.rb"
```

### ToolResultBlock

Result returned from a tool execution.

```ruby
ToolResultBlock = Data.define(:tool_use_id, :content, :is_error)
```

| Field         | Type           | Default  |
|---------------|----------------|----------|
| `tool_use_id` | `String`       | required |
| `content`     | `String, nil`  | `nil`    |
| `is_error`    | `Boolean, nil` | `nil`    |

Methods:

- `type` -- `:tool_result`
- `to_h` -- includes `content` and `is_error` only when non-nil

### ServerToolUseBlock

Tool use request for an MCP server tool.

```ruby
ServerToolUseBlock = Data.define(:id, :name, :input, :server_name)
```

| Field         | Type     | Default  |
|---------------|----------|----------|
| `id`          | `String` | required |
| `name`        | `String` | required |
| `input`       | `Hash`   | required |
| `server_name` | `String` | required |

Methods:

- `type` -- `:server_tool_use`
- `file_path` -- file path for file-based tools, else `nil`
- `display_label` -- label with server context (e.g., `"my-server/tool-name"`)
- `summary(max: 60)` -- detailed summary with server context, truncated
- `to_h` -- `{ type: "server_tool_use", id: id, name: name, input: input, server_name: server_name }`

### ServerToolResultBlock

Result from an MCP server tool execution.

```ruby
ServerToolResultBlock = Data.define(:tool_use_id, :content, :is_error, :server_name)
```

| Field         | Type           | Default  |
|---------------|----------------|----------|
| `tool_use_id` | `String`       | required |
| `server_name` | `String`       | required |
| `content`     | `String, nil`  | `nil`    |
| `is_error`    | `Boolean, nil` | `nil`    |

Methods:

- `type` -- `:server_tool_result`
- `to_h` -- includes `content` and `is_error` only when non-nil

### ImageContentBlock

Image content (base64-encoded or URL-sourced).

```ruby
ImageContentBlock = Data.define(:source)
```

| Field    | Type   | Default  |
|----------|--------|----------|
| `source` | `Hash` | required |

Methods:

- `type` -- `:image`
- `source_type` -- `"base64"` or `"url"`
- `media_type` -- MIME type (e.g., `"image/png"`)
- `data` -- base64-encoded image data
- `url` -- URL for URL-sourced images
- `to_h` -- `{ type: "image", source: source }`

```ruby
block = ImageContentBlock.new(source: { type: "base64", media_type: "image/png", data: "..." })
block.source_type  # => "base64"
block.media_type   # => "image/png"
```

### GenericBlock

Catch-all for unknown/future content block types. Supports dynamic field access.

```ruby
GenericBlock = Data.define(:block_type, :raw)
```

| Field        | Type     | Default  |
|--------------|----------|----------|
| `block_type` | `String` | required |
| `raw`        | `Hash`   | required |

Methods:

- `type` -- `block_type` as a symbol, or `:unknown`
- `to_h` -- returns `raw`
- `[](key)` -- hash-style access into `raw`
- `method_missing` -- dynamic field access into `raw`

---

## Common Patterns

### Iterating content blocks with case

```ruby
message.content.each do |block|
  case block
  when ClaudeAgent::TextBlock
    puts block.text
  when ClaudeAgent::ThinkingBlock
    puts "[thinking] #{block.thinking}"
  when ClaudeAgent::ToolUseBlock
    puts "Tool: #{block.display_label}"
  when ClaudeAgent::ServerToolUseBlock
    puts "MCP Tool: #{block.display_label}"
  when ClaudeAgent::ImageContentBlock
    puts "Image (#{block.media_type})"
  else
    puts "Unknown block: #{block.type}"
  end
end
```

### Filtering message streams

```ruby
messages = ClaudeAgent.query(prompt: "Hello", options: options).to_a

# Find the final result
result = messages.find { |m| m.is_a?(ClaudeAgent::ResultMessage) }

# Collect all assistant text
text = messages
  .select { |m| m.is_a?(ClaudeAgent::AssistantMessage) }
  .map(&:text)
  .join

# Stream deltas
messages.each do |msg|
  case msg
  when ClaudeAgent::StreamEvent
    print msg.delta_text if msg.delta_text
  when ClaudeAgent::ResultMessage
    puts "\nDone (#{msg.duration_ms}ms, $#{msg.total_cost_usd})"
  end
end
```

### Using text_content universally

```ruby
messages.each do |msg|
  text = msg.text_content
  puts text unless text.empty?
end
```

### Checking message identity

```ruby
messages.select(&:session_message?).each do |msg|
  puts "#{msg.type} [#{msg.uuid}] session=#{msg.session_id}"
end
```
