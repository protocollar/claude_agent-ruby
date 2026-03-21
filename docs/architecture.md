# Architecture

Internal architecture of the ClaudeAgent Ruby SDK.

---

## Layer Diagram

```
 ClaudeAgent.ask / .chat / .query
            |
 Configuration  (Stripe-style global defaults, Forwardable delegators)
            |
 Options  (validation, CLI arg serialization, env vars)
            |
 Conversation / Client  (lifecycle, turns, event dispatch)
            |
 EventHandler / TurnResult / CumulativeUsage
            |
 ControlProtocol  (request/response routing, hooks, MCP, permissions)
   Primitives | Lifecycle | Messaging | Commands | RequestHandling
            |
 Transport::Subprocess  (JSON Lines framing, stdin/stdout, process mgmt)
            |
 Claude Code CLI  (spawned as subprocess)
```

---

## Module Responsibilities

### Entry Points

| Module                   | Role                                                                                                  |
|--------------------------|-------------------------------------------------------------------------------------------------------|
| `ClaudeAgent.ask`        | One-shot query, returns `TurnResult`. Merges global config, builds `EventHandler` from `on_*` kwargs. |
| `ClaudeAgent.chat`       | Multi-turn conversation. Block form auto-cleans; no block returns `Conversation`.                     |
| `ClaudeAgent.query`      | Low-level streaming enumerator. Returns `Enumerator<Message>`.                                        |
| `ClaudeAgent.query_turn` | Like `query` but accumulates into `TurnResult` with optional `EventHandler`.                          |

### Configuration Layer

| Module          | Role                                                                                                                                                                                                                                                                                                           |
|-----------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Configuration` | Stripe-style global defaults. Holds all configurable fields (Tier 1/2/3), global `PermissionPolicy`, `HookRegistry`, and MCP server registrations. `to_options(**overrides)` merges config + per-request kwargs into an `Options` instance.                                                                    |
| `Options`       | All configurable attributes with validation and CLI arg serialization. Includes `Serializer` mixin for `to_cli_args` and `to_env`. Auto-compiles `PermissionPolicy` to lambda, `HookRegistry` to hash. Auto-sets `permission_prompt_tool_name = "stdio"` when `can_use_tool` or `permission_queue` is present. |

### Conversation Layer

| Module         | Role                                                                                                                                                                                                                                                                                                                                                                     |
|----------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Conversation` | High-level lifecycle manager. Wraps `Client` with auto-connect on first `say`, multi-turn history, tool activity timeline with timestamps, and cumulative cost tracking. Partitions kwargs into callbacks / conversation keys / options keys. Supports `open` (block), `resume` (session ID), and permission mode mapping (`:queue`, `:accept_edits`, policy, callable). |
| `Client`       | Bidirectional connection to CLI. Composes `Transport`, `ControlProtocol`, `EventHandler`, `CumulativeUsage`, and `PermissionQueue`. Provides `send_message`, `receive_turn`, `send_and_receive`, `stream_input`, `interrupt`, and `abort!`. Includes `Commands` mixin for control operations (permission mode, model changes, file rewind, MCP server management).       |

### Event & Accumulation Layer

| Module            | Role                                                                                                                                                                                                                                                                                                          |
|-------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `EventHandler`    | Three-layer event dispatch: (1) `:message` catch-all, (2) type-based (`:assistant`, `:stream_event`, `:status`, etc.), (3) decomposed (`:text`, `:thinking`, `:tool_use`, `:tool_result`). Pairs tool results with their originating tool use blocks. Supports `EventHandler.define` DSL and method chaining. |
| `TurnResult`      | Message accumulator for a single agent turn. Convenience accessors: `text`, `thinking`, `tool_uses`, `tool_results`, `tool_executions`, `cost`, `session_id`, `usage`, `model`, `structured_output`, `permission_denials`. Accumulates streaming text deltas as fallback for aborted turns.                   |
| `CumulativeUsage` | Thread-safe (Mutex) token and cost tracker across turns. Sums `input_tokens`, `output_tokens`, cache tokens. Takes session-cumulative `total_cost_usd` and `num_turns` from the most recent `ResultMessage`.                                                                                                  |

### Protocol Layer

| Module            | Role                                                                                                                                                                                                                                                                                                                                                              |
|-------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `ControlProtocol` | Core protocol handler. Composed of five submodules (below). Manages shared state: transport, parser, request counter, pending requests/results, threading primitives (Mutex, ConditionVariable, Queue), abort signal.                                                                                                                                             |
| `Primitives`      | Low-level read/write helpers. `write_message` serializes and sends JSON. Request/response ID generation. Stateless except for shared counters and pending-request maps.                                                                                                                                                                                           |
| `Lifecycle`       | Connection lifecycle: `start` (connect transport, spawn reader thread, send initialize), `stop` (end input, join reader, close transport), `abort!` (cancel pending requests, drain permission queue, terminate transport). Background `reader_loop` routes `control_request`, `control_response`, and SDK messages to appropriate handlers or the message queue. |
| `Messaging`       | Consumer-facing message delivery: `each_message`, `receive_response`, `send_user_message`, `stream_input`, `stream_conversation`. Reads from the internal `Queue`, parses via `MessageParser`, checks abort signal.                                                                                                                                               |
| `Commands`        | Control commands sent to CLI: `change_permission_mode`, `change_model`, `rewind_files`, `mcp_server_status`, `set_mcp_servers`, `interrupt`. Each sends a `control_request` and waits for the response.                                                                                                                                                           |
| `RequestHandling` | Handles incoming control requests from CLI: `can_use_tool` (three modes: synchronous callback, queue-based, default allow), `hook_callback`, `mcp_message` (routes to SDK MCP server instances), `elicitation`. Normalizes Ruby field names to CLI camelCase keys.                                                                                                |

### Transport Layer

| Module                  | Role                                                                                                                                                                                                                                                                                                                                                                     |
|-------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Transport::Base`       | Abstract base class defining the transport interface.                                                                                                                                                                                                                                                                                                                    |
| `Transport::Subprocess` | Spawns Claude Code CLI via `Open3.popen3` or custom spawn function. Manages stdin/stdout/stderr streams. JSON Lines framing with partial-JSON buffering. Version checking against minimum CLI version. Supports graceful termination (SIGTERM) and force kill (SIGKILL). Custom spawn support via `SpawnOptions` / `SpawnedProcess` for non-standard process management. |

### Parsing Layer

| Module          | Role                                                                                                                                                                                                                                                                    |
|-----------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `MessageParser` | Registry-based router. Maps raw JSON hashes (string keys, camelCase) to typed message objects. `deep_transform_keys` normalizes to snake_case symbols. Dispatches by `type` (top-level) or `type:subtype` (system messages). Unknown types wrapped in `GenericMessage`. |

### Permission System

| Module              | Role                                                                                                                                                                                                                                              |
|---------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `PermissionPolicy`  | Declarative DSL for permission rules: `allow`, `deny`, `allow_matching`, `deny_matching`, `allow_all`, `deny_all`, `ask` (custom fallback). Compiles to a `can_use_tool` lambda. Rules evaluated in order; first match wins.                      |
| `PermissionQueue`   | Thread-safe `Queue` wrapper for deferred permission requests. Non-blocking `poll`, blocking `pop(timeout:)`, and `drain!` for abort cleanup.                                                                                                      |
| `PermissionRequest` | Deferred permission request resolved from any thread. `allow!` / `deny!` unblock the reader thread via Mutex + ConditionVariable. Supports hybrid mode: callback can call `context.request.defer!` to enqueue instead of returning synchronously. |

### Hook System

| Module         | Role                                                                                                                                                                                                                                                                                                                                                                                                           |
|----------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `HookRegistry` | Ruby-friendly DSL mapping idiomatic method names (`before_tool_use`, `after_tool_use`, `on_session_start`, etc.) to CLI event names (`PreToolUse`, `PostToolUse`, `SessionStart`, etc.). `register` generates typed `Hook` subclasses and DSL methods by convention. Compiles to the `Hash{String => Array<Hook>}` format consumed by `Options#hooks`. Supports regex/string tool matchers and additive merge. |
| `Hook`         | Base hook type. Subclasses (e.g., `PreToolUseHook`) are generated per event by `HookRegistry.register`. Owns matching (`matches?`), CLI config serialization (`to_config`), and callback dispatch (`dispatch`). `event_name` is derived from the class name by convention.                                                                                                                                     |
| `HookInput`    | Dynamic wrapper for CLI hook input data. Base fields (`session_id`, `cwd`, etc.) are first-class readers; event-specific fields use `method_missing`. Frozen at construction.                                                                                                                                                                                                                                  |
| `HookContext`  | Structured context passed to hook callbacks. Currently carries `tool_use_id`.                                                                                                                                                                                                                                                                                                                                  |

### MCP Layer

| Module        | Role                                                                                                                                                                                       |
|---------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `MCP::Server` | In-process MCP server. Handles JSON-RPC messages: `initialize`, `tools/list`, `tools/call`. Registered via `Options#mcp_servers` with `type: "sdk"`. Block DSL for inline tool definition. |
| `MCP::Tool`   | Single tool definition with name, description, JSON Schema (auto-normalized from Ruby types/symbols), optional annotations, and handler block. Formats results as MCP content blocks.      |

### Session Layer

| Module                   | Role                                                                                                                                                                                                                             |
|--------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Session`                | Rails-like finder with Stripe-style resource methods. `find` / `retrieve` / `all` / `where` class methods. Instance methods: `messages` (returns `SessionMessageRelation`), `rename`, `tag_session`, `fork`, `reload`, `resume`. |
| `SessionMessageRelation` | Chainable Enumerable query object. Lazy evaluation with `where(limit:, offset:)`. Wraps `GetSessionMessages`.                                                                                                                    |
| `ListSessions`           | Reads session metadata from disk without spawning CLI. Returns `SessionInfo` sorted by last modified. Supports directory scoping and git worktree inclusion.                                                                     |
| `GetSessionMessages`     | Reads JSONL session transcript, reconstructs main conversation thread, returns `SessionMessage` array with pagination.                                                                                                           |
| `GetSessionInfo`         | Targeted single-session lookup by UUID.                                                                                                                                                                                          |
| `ForkSession`            | Creates a new session file with remapped UUIDs, optional truncation point.                                                                                                                                                       |
| `SessionMutations`       | Appends `custom-title` and `tag` entries to session files.                                                                                                                                                                       |
| `SessionPaths`           | Shared infrastructure for resolving session file paths across projects and worktrees.                                                                                                                                            |

### Abort & Signal

| Module            | Role                                                                                                                                                                                                                                           |
|-------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `AbortController` | JavaScript-style abort controller. Owns an `AbortSignal`. `abort(reason)` triggers the signal; `reset!` clears it for reuse.                                                                                                                   |
| `AbortSignal`     | Thread-safe (Mutex + ConditionVariable) signal. `aborted?`, `reason`, `on_abort` callbacks, `wait(timeout:)`, `check!` (raises `AbortError`). Used by `ControlProtocol` (reader loop check, queue push), `Conversation` (auto-reset per turn). |

### Tool Activity Tracking

| Module                | Role                                                                                                                                                                                                         |
|-----------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `ToolActivity`        | Immutable (`ImmutableRecord`) record of a completed tool execution. Pairs `ToolUseBlock` + `ToolResultBlock` with turn index and wall-clock timestamps.                                                      |
| `LiveToolActivity`    | Mutable wrapper for real-time status tracking. States: `:running`, `:done`, `:error`. Updated by progress messages. Suitable for live UIs.                                                                   |
| `ToolActivityTracker` | Enumerable collection with auto-wiring. Attaches to `EventHandler` or `Client`. Callbacks: `on_start`, `on_complete`, `on_progress`, `on_change`. Query methods: `running`, `done`, `errored`, `find_by_id`. |

---

## Data Flow

### One-Shot Query (`ask`)

```
User calls ClaudeAgent.ask(prompt, **kwargs)
  |
  +-- extract_callbacks separates on_* from config overrides
  +-- Configuration.to_options merges global defaults + overrides --> Options
  +-- build_events creates EventHandler from callbacks
  |
  +-- query_turn(prompt, options, events)
        |
        +-- ClaudeAgent.query(prompt, options) returns Enumerator
        |     |
        |     +-- Transport::Subprocess.new(options)
        |     +-- ControlProtocol.new(transport, options)
        |     +-- protocol.start(streaming: true)
        |     |     +-- transport.connect --> spawn CLI subprocess
        |     |     +-- reader_loop starts in background Thread
        |     |     +-- send_initialize --> handshake with CLI
        |     +-- protocol.send_user_message(prompt)
        |     |     +-- write JSON to stdin
        |     +-- protocol.each_message yields parsed messages
        |           +-- reader_loop reads JSON Lines from stdout
        |           +-- routes control_request to RequestHandling
        |           +-- routes control_response to pending request
        |           +-- queues SDK messages for consumer
        |           +-- consumer pops from Queue
        |           +-- MessageParser.parse(raw) --> typed message
        |           +-- yield message to Enumerator
        |
        +-- TurnResult << message (accumulates)
        +-- EventHandler.handle(message) (dispatches events)
        +-- yield message to caller block (if given)
        +-- return TurnResult
```

### Multi-Turn Conversation (`chat`)

```
User calls ClaudeAgent.chat(**kwargs)
  |
  +-- merge_config_into_kwargs applies global defaults
  +-- Conversation.new(**merged)
        |
        +-- partition_kwargs --> callbacks / conversation_kwargs / options_kwargs
        +-- build_options (compiles PermissionPolicy, HookRegistry, permission mode)
        +-- Client.new(options)
        +-- register_callbacks on Client's EventHandler
        +-- register_timing_hooks for tool activity timestamps
  |
  +-- conversation.say(prompt)
        |
        +-- ensure_connected! (auto-connects on first call)
        |     +-- Client.connect
        |     +-- ControlProtocol.start(streaming: true)
        +-- Client.send_and_receive(prompt)
        |     +-- send_message --> protocol.send_user_message
        |     +-- receive_turn
        |           +-- TurnResult.new
        |           +-- receive_response yields messages
        |           +-- TurnResult << message
        |           +-- EventHandler.handle(message)
        |           +-- CumulativeUsage.track(message)
        |           +-- stops on ResultMessage
        +-- build_tool_activities (timestamps from hooks)
        +-- return TurnResult
```

### Permission Request Flow

```
CLI sends control_request { subtype: "can_use_tool" }
  |
  +-- reader_loop receives raw message
  +-- handle_control_request dispatches to handle_can_use_tool
  |
  +-- Mode 1: Synchronous callback
  |     +-- options.can_use_tool.call(name, input, context)
  |     +-- callback returns PermissionResultAllow or PermissionResultDeny
  |     +-- (or callback calls context.request.defer! to switch to queue mode)
  |
  +-- Mode 2: Queue-based
  |     +-- PermissionRequest created with Mutex + ConditionVariable
  |     +-- pushed to PermissionQueue
  |     +-- reader thread blocks on perm_request.wait(timeout:)
  |     +-- main thread polls client.pending_permission
  |     +-- main thread calls request.allow! or request.deny!
  |     +-- ConditionVariable.broadcast unblocks reader thread
  |
  +-- Mode 3: Default allow (no callback, no queue)
  |
  +-- normalize_permission_result --> Hash
  +-- send_control_response back to CLI
```

---

## Immutable Types

All message types and content blocks inherit from `ImmutableRecord`, frozen at construction:

**Messages**: `UserMessage`, `UserMessageReplay`, `AssistantMessage`, `SystemMessage`, `ResultMessage`, `StreamEvent`, `CompactBoundaryMessage`, `StatusMessage`, `ToolProgressMessage`, `HookResponseMessage`, `AuthStatusMessage`, `TaskNotificationMessage`, `HookStartedMessage`, `HookProgressMessage`, `ToolUseSummaryMessage`, `FilesPersistedEvent`, `TaskStartedMessage`, `TaskProgressMessage`, `RateLimitEvent`, `PromptSuggestionMessage`, `ElicitationCompleteMessage`, `LocalCommandOutputMessage`, `GenericMessage`

**Content Blocks**: `TextBlock`, `ThinkingBlock`, `ToolUseBlock`, `ToolResultBlock`, `ServerToolUseBlock`, `ServerToolResultBlock`, `ImageContentBlock`, `GenericBlock`

**Data Types**: `SessionInfo`, `SessionMessage`, `ForkSessionResult`, `ToolActivity`, `TaskUsage`, `SDKPermissionDenial`, `RewindFilesResult`, `ToolsPreset`, `SlashCommand`, `McpServerStatus`, `McpSetServersResult`, `PermissionResultAllow`, `PermissionResultDeny`

---

## Thread Safety

| Component                                   | Mechanism                     | Purpose                                                                                            |
|---------------------------------------------|-------------------------------|----------------------------------------------------------------------------------------------------|
| `PermissionRequest`                         | `Mutex` + `ConditionVariable` | Reader thread blocks on `wait`; main thread resolves via `allow!` / `deny!`                        |
| `PermissionQueue`                           | `Queue` (thread-safe stdlib)  | Bridges reader thread and consumer thread for permission requests                                  |
| `AbortSignal`                               | `Mutex` + `ConditionVariable` | Multiple consumers check `aborted?`; `on_abort` callbacks fire once; `wait` blocks until triggered |
| `CumulativeUsage`                           | `Mutex`                       | All reads and writes synchronized                                                                  |
| `ControlProtocol`                           | `Mutex` + `ConditionVariable` | Shared state for pending requests/results; reader thread signals consumer                          |
| `Transport::Subprocess`                     | `Mutex`                       | Protects stdin writes and stream close operations                                                  |
| `ControlProtocol.reader_loop`               | Background `Thread`           | Reads transport, routes control messages, queues SDK messages                                      |
| `Transport::Subprocess.start_stderr_reader` | Background `Thread`           | Drains stderr to prevent pipe buffer fill; forwards to `stderr_callback`                           |

---

## Types Reference

### Core Return Types

| Type              | Description                                                                                                                                                                                                    |
|-------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `TurnResult`      | Accumulator for a single turn. Accessors: `text`, `thinking`, `tool_uses`, `tool_results`, `tool_executions`, `cost`, `session_id`, `usage`, `model`, `stop_reason`, `structured_output`, `permission_denials` |
| `CumulativeUsage` | Cross-turn token/cost tracker. Fields: `input_tokens`, `output_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens`, `total_cost_usd`, `num_turns`, `duration_ms`, `duration_api_ms`              |
| `EventHandler`    | Event dispatcher. Events: `message`, `user`, `assistant`, `system`, `result`, `stream_event`, `status`, `tool_progress`, `text`, `thinking`, `tool_use`, `tool_result`, and more                               |

### Tool Activity

| Type                  | Description                                                                                   |
|-----------------------|-----------------------------------------------------------------------------------------------|
| `ToolActivity`        | Immutable. Post-turn record of a tool execution with timestamps and turn index                |
| `LiveToolActivity`    | Mutable. Real-time status (`:running`, `:done`, `:error`) with elapsed time                   |
| `ToolActivityTracker` | Enumerable collection with `on_start` / `on_complete` / `on_progress` / `on_change` callbacks |

### Permissions

| Type                    | Description                                                                                                                                                  |
|-------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `PermissionRequest`     | Deferred request with `allow!` / `deny!` / `defer!`. Thread-safe resolution                                                                                  |
| `PermissionQueue`       | Thread-safe queue with `poll` (non-blocking) and `pop` (blocking)                                                                                            |
| `PermissionPolicy`      | Declarative DSL. Compiles to `can_use_tool` lambda                                                                                                           |
| `PermissionResultAllow` | Allow response with optional `updated_input` and `updated_permissions`                                                                                       |
| `PermissionResultDeny`  | Deny response with `message` and `interrupt` flag                                                                                                            |
| `ToolPermissionContext` | Context passed to `can_use_tool`: `permission_suggestions`, `blocked_path`, `decision_reason`, `tool_use_id`, `agent_id`, `description`, `signal`, `request` |

### Sessions

| Type                     | Description                                                                                                                                         |
|--------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------|
| `Session`                | Rich finder object. Class methods: `find`, `retrieve`, `all`, `where`. Instance: `messages`, `rename`, `fork`, `resume`, `reload`                   |
| `SessionInfo`            | Immutable metadata: `session_id`, `summary`, `last_modified`, `file_size`, `custom_title`, `first_prompt`, `git_branch`, `cwd`, `tag`, `created_at` |
| `SessionMessage`         | Immutable transcript entry: `type`, `uuid`, `session_id`, `message`, `parent_tool_use_id`                                                           |
| `SessionMessageRelation` | Chainable Enumerable with `where(limit:, offset:)`                                                                                                  |
| `ForkSessionResult`      | Fork result with new `session_id`                                                                                                                   |

### MCP

| Type                  | Description                                                                                   |
|-----------------------|-----------------------------------------------------------------------------------------------|
| `MCP::Server`         | In-process MCP server hosting `MCP::Tool` instances                                           |
| `MCP::Tool`           | Tool definition with schema normalization and handler block                                   |
| `McpServerStatus`     | Status of an MCP server: `name`, `status`, `server_info`, `error`, `config`, `scope`, `tools` |
| `McpSetServersResult` | Result of dynamic server management: `added`, `removed`, `errors`                             |

### Abort

| Type              | Description                                                                               |
|-------------------|-------------------------------------------------------------------------------------------|
| `AbortController` | Owns an `AbortSignal`. Methods: `abort(reason)`, `reset!`                                 |
| `AbortSignal`     | Thread-safe signal. Methods: `aborted?`, `reason`, `on_abort`, `wait`, `check!`, `reset!` |

---

## Development

```bash
bin/setup                          # Install dependencies
bundle exec rake                   # Unit tests + RBS + RuboCop (default task)
bundle exec rake test              # Unit tests only
bundle exec rake test_integration  # Integration tests (requires CLI v2.0.0+)
bundle exec rake test_smoke        # Smoke tests against local LLM (e.g. Ollama)
bundle exec rake test_all          # All tests
bundle exec rake rbs               # Validate RBS type signatures
bundle exec rubocop                # Lint
bin/console                        # IRB with gem loaded
```

**Binstubs**: `bin/test`, `bin/test-integration`, `bin/test-all`, `bin/test-smoke`, `bin/rbs-validate`

**Test structure**: Unit tests in `test/claude_agent/` (no CLI required), integration tests in `test/integration/` (require `INTEGRATION=true`), smoke tests in `test/smoke/` (require Ollama + `SMOKE=true`). Support files and mocks in `test/support/`.

**Single file**: `bundle exec ruby -Itest test/claude_agent/test_foo.rb`
