# Sessions

Claude Code CLI persists every conversation as a session on disk. The SDK can find, inspect, mutate, fork, and resume these sessions without spawning a CLI subprocess -- all operations read and write the session JSONL files directly.

## Session Resource

The `Session` class wraps `SessionInfo` with a rich, Rails-like API for discovering and working with past sessions.

### Finding a Session

Use `Session.find` for a safe lookup that returns `nil` when the session does not exist, or `Session.retrieve` when you want an exception on missing sessions.

```ruby
# Returns Session or nil (targeted lookup by ID, not a full scan)
session = ClaudeAgent::Session.find("abc-123-def-456")

# Returns Session or raises ClaudeAgent::NotFoundError
session = ClaudeAgent::Session.retrieve("abc-123-def-456")
```

Both accept an optional `dir:` keyword to scope the search to a specific project directory:

```ruby
session = ClaudeAgent::Session.find("abc-123-def-456", dir: "/path/to/project")
```

### Listing Sessions

```ruby
# All sessions across all projects, sorted by last modified (most recent first)
sessions = ClaudeAgent::Session.all

# With optional filters
sessions = ClaudeAgent::Session.where(dir: "/path/to/project", limit: 10)
```

### Fields

Every `Session` exposes the following attributes:

| Field           | Type             | Description                                                                       |
|-----------------|------------------|-----------------------------------------------------------------------------------|
| `session_id`    | `String`         | UUID of the session.                                                              |
| `summary`       | `String`         | Display summary: custom title, last auto-summary, first prompt, or `"(session)"`. |
| `last_modified` | `Integer`        | Last modification time as epoch milliseconds.                                     |
| `file_size`     | `Integer`        | Size of the session JSONL file in bytes.                                          |
| `custom_title`  | `String`, `nil`  | User-assigned title, if any.                                                      |
| `first_prompt`  | `String`, `nil`  | First meaningful user prompt (truncated to 200 chars).                            |
| `git_branch`    | `String`, `nil`  | Git branch active during the session.                                             |
| `cwd`           | `String`, `nil`  | Working directory the session was started in.                                     |
| `tag`           | `String`, `nil`  | User-assigned tag, if any.                                                        |
| `created_at`    | `Integer`, `nil` | Creation timestamp (epoch milliseconds), if available.                            |

```ruby
session = ClaudeAgent::Session.retrieve("abc-123-def-456")

puts session.summary        # => "Fix login bug"
puts session.git_branch     # => "fix/login"
puts session.custom_title   # => nil (no custom title set)
puts session.cwd            # => "/Users/dev/myapp"
```

### Messages

`session.messages` returns a chainable, `Enumerable` `SessionMessageRelation`. Messages are loaded lazily on first access.

```ruby
session = ClaudeAgent::Session.retrieve("abc-123-def-456")

# All messages
session.messages.each { |m| puts "#{m.type}: #{m.uuid}" }

# Pagination via .where
session.messages.where(limit: 10).to_a
session.messages.where(limit: 10, offset: 5).to_a

# Enumerable methods work directly
session.messages.first
session.messages.count
session.messages.select { |m| m.type == "assistant" }
session.messages.map(&:uuid)
```

Each message in the relation is a `SessionMessage` with these fields:

| Field                | Type            | Description                                       |
|----------------------|-----------------|---------------------------------------------------|
| `type`               | `String`        | `"user"` or `"assistant"`.                        |
| `uuid`               | `String`        | Message UUID.                                     |
| `session_id`         | `String`        | Session UUID this message belongs to.             |
| `message`            | `Hash`          | Raw message payload (role, content blocks, etc.). |
| `parent_tool_use_id` | `String`, `nil` | Parent tool use ID for tool result messages.      |

### Mutations

#### Renaming

```ruby
session.rename("My descriptive title")
session.custom_title  # => "My descriptive title"
```

Appends a `custom-title` JSONL entry to the session file. The `custom_title` attribute is updated in place.

#### Tagging

```ruby
session.tag_session("important")
session.tag  # => "important"

# Clear the tag
session.tag_session(nil)
session.tag  # => nil
```

Appends a `tag` JSONL entry. Unicode zero-width and directional characters are automatically stripped from tag values.

Both mutations return `self` for chaining:

```ruby
session.rename("Refactored auth module").tag_session("refactor")
```

### Forking

Create a new session by copying an existing one. All UUIDs in the forked session are remapped to fresh values.

```ruby
# Fork the entire session
forked = session.fork
forked.session_id  # => new UUID

# Fork up to a specific message (inclusive)
forked = session.fork(up_to: "message-uuid-here")

# Fork with a custom title
forked = session.fork(title: "Branch: try alternative approach")
```

The returned value is a new `Session` instance pointing to the forked session file.

### Reloading

Re-read session metadata from disk to pick up external changes:

```ruby
session.reload
session.summary  # reflects current file state
```

Raises `ClaudeAgent::NotFoundError` if the session file no longer exists.

### Resuming

Open a `Conversation` that continues from this session. The CLI restores full conversation context from the session transcript.

```ruby
# Block form -- auto-closes when the block exits
session.resume(model: "opus") do |c|
  turn = c.say("Continue where we left off")
  puts turn.text
end

# Without a block -- caller is responsible for closing
conversation = session.resume(max_turns: 5)
conversation.say("What did we discuss last time?")
conversation.close
```

Accepts the same keyword arguments as `Conversation.new`.

## Functional API

The module-level methods provide direct access to session operations without wrapping results in `Session` objects. These return the underlying data types (`SessionInfo`, `SessionMessage`, `ForkSessionResult`) and are useful when you need lower-level control.

### `ClaudeAgent.list_sessions`

```ruby
# All sessions
sessions = ClaudeAgent.list_sessions
# => Array<SessionInfo>

# Scoped to a directory with pagination
sessions = ClaudeAgent.list_sessions(
  dir: "/path/to/project",
  limit: 20,
  offset: 10,
  include_worktrees: true   # default: true
)
```

When `dir` is inside a git repository and `include_worktrees` is `true`, sessions from all git worktree paths are included automatically.

### `ClaudeAgent.get_session_info`

Targeted lookup of a single session by UUID. Returns `SessionInfo` or `nil`.

```ruby
info = ClaudeAgent.get_session_info("abc-123-def-456")
info = ClaudeAgent.get_session_info("abc-123-def-456", dir: "/path/to/project")
```

### `ClaudeAgent.get_session_messages`

Read the conversation transcript for a session. Returns user and assistant messages in chronological order, reconstructing the main conversation thread from branches and forks.

```ruby
messages = ClaudeAgent.get_session_messages("abc-123-def-456")
# => Array<SessionMessage>

messages = ClaudeAgent.get_session_messages("abc-123-def-456",
  dir: "/path/to/project",
  limit: 10,
  offset: 5
)
```

### `ClaudeAgent.rename_session`

```ruby
ClaudeAgent.rename_session("abc-123-def-456", "New title")
ClaudeAgent.rename_session("abc-123-def-456", "New title", dir: "/path/to/project")
```

Raises `ArgumentError` if the title is empty, `ClaudeAgent::Error` if the session is not found.

### `ClaudeAgent.tag_session`

```ruby
ClaudeAgent.tag_session("abc-123-def-456", "important")
ClaudeAgent.tag_session("abc-123-def-456", nil)  # clear tag
ClaudeAgent.tag_session("abc-123-def-456", "v2", dir: "/path/to/project")
```

Raises `ClaudeAgent::Error` if the session is not found.

### `ClaudeAgent.fork_session`

```ruby
result = ClaudeAgent.fork_session("abc-123-def-456")
# => ForkSessionResult

result.session_id  # => new UUID

result = ClaudeAgent.fork_session("abc-123-def-456",
  up_to_message_id: "msg-uuid",
  title: "Forked conversation",
  dir: "/path/to/project"
)
```

Raises `ArgumentError` if `up_to_message_id` is provided but not found in the session transcript.

## V2 Session API (Unstable)

> **Warning:** The V2 Session API is unstable and may change without notice in any release. It is marked `@alpha` in the source and should not be used in production.

The V2 API provides a lower-level, multi-turn session interface that maps directly to the TypeScript SDK's `SDKSession` pattern. Unlike `Conversation`, it gives you explicit control over send/stream cycles.

### Creating a Session

```ruby
session = ClaudeAgent.unstable_v2_create_session(
  model: "claude-sonnet-4-5-20250929",
  permission_mode: "acceptEdits"
)
```

### Sending and Streaming

```ruby
session.send("Hello, Claude!")

session.stream.each do |msg|
  case msg
  when ClaudeAgent::AssistantMessage
    print msg.text
  when ClaudeAgent::ResultMessage
    puts "\nDone!"
  end
end
```

### Resuming

```ruby
session = ClaudeAgent.unstable_v2_resume_session(
  "session-abc-123",
  model: "claude-sonnet-4-5-20250929"
)
session.send("Continue our conversation")
session.stream.each { |msg| puts msg.inspect }
session.close
```

### One-Shot Prompt

```ruby
result = ClaudeAgent.unstable_v2_prompt(
  "What files are in this directory?",
  model: "claude-sonnet-4-5-20250929"
)
puts result.text
```

### SessionOptions

`SessionOptions` is an `ImmutableRecord` type with the following fields:

| Field                            | Type            | Description                                        |
|----------------------------------|-----------------|----------------------------------------------------|
| `model`                          | `String`        | Model identifier (required).                       |
| `path_to_claude_code_executable` | `String`, `nil` | Custom path to the Claude Code CLI binary.         |
| `env`                            | `Hash`, `nil`   | Environment variables to pass to the CLI process.  |
| `allowed_tools`                  | `Array`, `nil`  | Tools the agent is allowed to use.                 |
| `disallowed_tools`               | `Array`, `nil`  | Tools the agent is not allowed to use.             |
| `can_use_tool`                   | `Proc`, `nil`   | Callback for dynamic tool permission decisions.    |
| `hooks`                          | `Hash`, `nil`   | Hook configuration.                                |
| `permission_mode`                | `String`, `nil` | Permission mode (e.g., `"acceptEdits"`, `"plan"`). |

### Lifecycle

Always close V2 sessions when done to clean up the underlying CLI subprocess:

```ruby
session = ClaudeAgent.unstable_v2_create_session(model: "claude-sonnet-4-5-20250929")
begin
  session.send("Do something")
  session.stream.each { |msg| process(msg) }
ensure
  session.close
end

session.closed?  # => true
```
