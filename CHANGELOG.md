# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `AgentInfo` type with `name`, `description`, and `model` fields (TypeScript SDK v0.2.63 parity)
- `supported_agents` control request on `ControlProtocol` and `Client` for querying available subagents (TypeScript SDK v0.2.63 parity)
- `agents` field on `InitializationResult` returning `AgentInfo[]`
- `fast_mode_state` field on `ResultMessage` (TypeScript SDK v0.2.63 parity)
- `ElicitationCompleteMessage` for MCP elicitation completion events (TypeScript SDK v0.2.63 parity)
- `LocalCommandOutputMessage` for local command output events (TypeScript SDK v0.2.63 parity)
- `on_elicitation` option for handling MCP elicitation requests via callback (TypeScript SDK v0.2.63 parity)
- `Elicitation` and `ElicitationResult` hook events with input types (TypeScript SDK v0.2.63 parity)
- Elicitation control protocol handling with callback support and default decline behavior
- `on_elicitation_complete` and `on_local_command_output` event handler methods
- RBS signatures for all new types, fields, and methods

## [0.7.12] - 2026-02-27

### Added
- `ResultMessage#uuid` field (TypeScript SDK parity — every other message type already had it)
- `sdkMcpServers` is now sent in the initialize request when SDK MCP servers are configured (TypeScript SDK parity)
- `abort!` now sends `control_cancel_request` for each pending request before failing them locally (TypeScript SDK parity)

## [0.7.11] - 2026-02-27

### Added
- `LiveToolActivity` — mutable, real-time tool status tracker (`:running` → `:done`/`:error`) with elapsed time and delegation to `ToolUseBlock`
- `ToolActivityTracker` — `Enumerable` collection that auto-wires to `EventHandler` or `Client` via `.attach`, with `on_start`/`on_complete`/`on_progress` callbacks, `on_change` catch-all, `running`/`done`/`errored` filtered views, and `reset!`
- `Conversation` accepts `track_tools: true` to opt into live tool tracking via `tool_tracker` accessor
- Convention-based event dispatch — every message type now auto-fires a dedicated event based on `message.type` (e.g. `:assistant`, `:stream_event`, `:status`, `:tool_progress`)
- `EventHandler::EVENTS`, `TYPE_EVENTS`, `DECOMPOSED_EVENTS`, `META_EVENTS` constants enumerating all known events
- `on_assistant`, `on_user`, `on_stream_event`, `on_status`, `on_tool_progress`, `on_hook_response`, `on_auth_status`, `on_task_notification`, `on_hook_started`, `on_hook_progress`, `on_tool_use_summary`, `on_task_started`, `on_task_progress`, `on_rate_limit_event`, `on_prompt_suggestion`, `on_files_persisted` convenience methods on `EventHandler` and `Client`
- `Conversation` now accepts any `on_*` keyword argument as a callback (pattern-based, no longer limited to a hardcoded list)
- `GenericMessage` fires its dynamic type symbol, so `on(:fancy_new_type)` works for future/unknown CLI message types
- `TaskNotificationMessage#tool_use_id` and `#usage` fields with new `TaskUsage` type (TypeScript SDK parity)
- `ToolProgressMessage#task_id` field (TypeScript SDK parity)
- `StatusMessage#permission_mode` field (TypeScript SDK parity)
- `ModelInfo#supports_effort`, `#supported_effort_levels`, `#supports_adaptive_thinking` fields (TypeScript SDK parity)
- `McpServerStatus#error`, `#config`, `#scope`, `#tools` fields (TypeScript SDK parity)
- `StopInput#last_assistant_message` hook field (TypeScript SDK parity)
- `SubagentStopInput#agent_type` and `#last_assistant_message` hook fields (TypeScript SDK parity)
- `'oauth'` source in `API_KEY_SOURCES` constant (TypeScript SDK parity)
- RBS signatures for all new fields

### Changed
- `EventHandler#handle` now fires three layers per message: `:message` (catch-all) → `message.type` (type-based) → decomposed (`:text`, `:thinking`, `:tool_use`, `:tool_result`)
- `Conversation::CONVERSATION_KEYS` now contains only infrastructure keys (`client`, `options`, `on_permission`); callback detection is pattern-based via `on_*` prefix

## [0.7.10] - 2026-02-26

### Added
- `Session.find(id, dir:)` — find a past session by UUID, returns `Session` or `nil`
- `Session.all` — list all past sessions as `Session` objects
- `Session.where(dir:, limit:)` — query sessions with optional directory and limit filters
- `Session#messages` — returns a chainable, `Enumerable` `SessionMessageRelation` for reading transcript messages
- `SessionMessageRelation#where(limit:, offset:)` — paginate messages with immutable chaining
- `ClaudeAgent.get_session_messages(session_id, dir:, limit:, offset:)` — read session transcripts from disk (TypeScript SDK v0.2.59 parity)
- `SessionMessage` type — message from a session transcript with `type`, `uuid`, `session_id`, `message`
- `SessionPaths` module — shared path infrastructure for session discovery (extracted from `ListSessions`)

### Changed
- Renamed `Session` (V2 multi-turn API) to `V2Session` to free the `Session` name for the finder API
- `unstable_v2_create_session`, `unstable_v2_resume_session`, and `unstable_v2_prompt` now return `V2Session`

## [0.7.9] - 2026-02-25

### Added
- `Conversation` — high-level wrapper managing the full conversation lifecycle with auto-connect, multi-turn history, callbacks, and tool activity timeline
- `Conversation#say(prompt)` — send a message and receive a `TurnResult`, auto-connecting on first call
- `Conversation.open { |c| ... }` — block form with automatic cleanup
- `Conversation.resume(session_id)` — resume a previous conversation
- `Conversation` callbacks: `on_text`, `on_stream`, `on_tool_use`, `on_tool_result`, `on_thinking`, `on_result`, `on_message`, `on_permission`
- `Conversation#total_cost`, `#session_id`, `#usage`, `#pending_permission`, `#pending_permissions?` — convenience accessors
- `ClaudeAgent.conversation(**kwargs)` and `ClaudeAgent.resume_conversation(session_id)` — module-level convenience methods
- `ToolActivity` — immutable `Data.define` pairing a `ToolUseBlock` with its `ToolResultBlock`, turn index, and timing; delegates `name`, `display_label`, `summary`, `file_path`, `id` to the tool use block
- `Conversation#tool_activity` — unified timeline of all tool executions across turns with duration tracking
- `PermissionRequest` — deferred permission promise that can be resolved from any thread via `allow!` / `deny!`, with `defer!` for hybrid callback/queue mode
- `PermissionQueue` — thread-safe queue of pending `PermissionRequest` objects with `poll`, `pop(timeout:)`, and `drain!`
- `Client#permission_queue` — returns the queue; always available on connected clients
- `Client#pending_permission` — non-blocking poll for the next pending permission request
- `Client#pending_permissions?` — check if any permission requests are waiting
- `Options#permission_queue` — set to `true` to enable queue-based permissions (auto-sets `permission_prompt_tool_name: "stdio"`)
- `ToolPermissionContext#request` — access the `PermissionRequest` from within a `can_use_tool` callback for hybrid defer mode
- `ControlProtocol` now supports three permission modes: synchronous callback, queue-based, and hybrid (callback with selective `defer!`)
- `TurnResult` — represents a complete agent turn, accumulating all messages between sending a prompt and receiving the `ResultMessage`
- `TurnResult#text`, `#thinking` — concatenated text/thinking across all assistant messages
- `TurnResult#tool_uses`, `#tool_results`, `#tool_executions` — tool use blocks, result blocks, and matched use/result pairs
- `TurnResult#usage`, `#cost`, `#duration_ms`, `#session_id`, `#model`, `#success?`, `#error?` — convenient accessors from the result
- `Client#send_and_receive(content)` — send a message and receive the complete `TurnResult` in one call
- `Client#receive_turn` — like `receive_response` but returns a `TurnResult` instead of yielding raw messages
- `ClaudeAgent.query_turn(prompt:)` — one-shot query returning a `TurnResult`
- `EventHandler` — register typed event callbacks (`:text`, `:thinking`, `:tool_use`, `:tool_result`, `:result`, `:message`) instead of writing `case` statements over raw messages
- `Client#on(event, &block)` and `#on_text`, `#on_tool_use`, `#on_tool_result`, `#on_result`, etc. — register persistent event handlers that fire during `receive_turn` and `send_and_receive`
- `ClaudeAgent.query_turn` now accepts `events:` parameter for standalone `EventHandler` use
- `TaskProgressMessage` for real-time background task (subagent) progress reporting (TypeScript SDK v0.2.51 parity)
- `mcp_authenticate` control request on `ControlProtocol` and `Client` for MCP server OAuth authentication (TypeScript SDK v0.2.52 parity)
- `mcp_clear_auth` control request on `ControlProtocol` and `Client` for clearing MCP server credentials (TypeScript SDK v0.2.52 parity)
- RBS signatures for all new types and methods
- `CumulativeUsage` — built-in cumulative usage tracking across conversation turns; automatically updated by `Client` as `ResultMessage`s are received
- `Client#cumulative_usage` — returns the usage accumulator with `input_tokens`, `output_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens`, `total_cost_usd`, `num_turns`, `duration_ms`, `duration_api_ms`
- `GenericMessage` type — wraps unknown top-level message types instead of raising `MessageParseError`, with dynamic field access via `[]` and `method_missing`
- `GenericBlock` type — wraps unknown content block types instead of returning raw Hashes, with dynamic field access via `[]` and `method_missing`
- `ToolUseBlock#file_path` — returns the file path for file-based tools (`Read`, `Write`, `Edit`, `NotebookEdit`), nil otherwise
- `ToolUseBlock#display_label` — one-line human-readable label (e.g. `"Read lib/foo.rb"`, `"Bash: git status"`, `"WebFetch: example.com"`)
- `ToolUseBlock#summary(max:)` — detailed summary with truncation (e.g. `"Write: /path.rb (3 lines)"`, `"Grep: pattern in /path (*.rb)"`)
- `ServerToolUseBlock#file_path`, `#display_label`, `#summary(max:)` — same interface with server context (e.g. `"server_name/tool_name"`)

### Changed
- `BaseHookInput.define_input` — declarative macro for generating hook input subclasses from a single declaration; replaces 18 hand-written classes with one-line definitions
- `MessageParser` now uses a registry pattern (`MessageParser.register`) instead of nested `case` statements for message routing; adding a new message type is one `register` call
- `MessageParser#parse` no longer raises `MessageParseError` for unknown message types; returns `GenericMessage` instead
- `MessageParser#parse_content_block` no longer returns raw Hashes for unknown content block types; returns `GenericBlock` instead
- All parsed message hashes now use snake_case symbol keys throughout (e.g. `msg.usage[:input_tokens]`, `event.files.first[:filename]`, `event.event[:type]`)
- `MessageParser#parse` applies a single `deep_transform_keys` pass that normalizes camelCase→snake_case and string→symbol for the entire hash tree
- `can_use_tool` callbacks receive symbol-keyed `input` hashes
- Hook callbacks receive symbol-keyed `input` hashes
- MCP tool handlers receive symbol-keyed `arguments` hashes

### Removed
- `MessageParser#fetch_dual` — no longer needed now that keys are normalized at the entry point

## [0.7.8] - 2026-02-22

### Added
- `WorktreeCreate` hook event with `WorktreeCreateInput` class (TypeScript SDK v0.2.50 parity)
- `WorktreeRemove` hook event with `WorktreeRemoveInput` class (TypeScript SDK v0.2.50 parity)
- `apply_flag_settings` control request on `ControlProtocol` and `Client` for merging settings into the flag layer (TypeScript SDK v0.2.50 parity)
- RBS signatures for all new types

## [0.7.7] - 2026-02-20

### Added
- `TaskStartedMessage` for background task start notifications (TypeScript SDK v0.2.43 parity)
- `RateLimitEvent` message type for rate limit visibility (TypeScript SDK v0.2.44 parity)
- `PromptSuggestionMessage` type and `prompt_suggestions` option for suggested follow-up prompts (TypeScript SDK v0.2.46 parity)
- `ConfigChange` hook event with `ConfigChangeInput` class (TypeScript SDK v0.2.47 parity)
- `SandboxFilesystemConfig` with `allow_write`, `deny_write`, `deny_read` fields (TypeScript SDK v0.2.49 parity)
- RBS signatures for all new types

## [0.7.6] - 2026-02-13

### Added
- `stop_task` control request and `Client#stop_task` method for stopping running background tasks (TypeScript SDK parity)

## [0.7.5] - 2026-02-10

### Added
- `thinking` option for controlling extended thinking mode (`{ type: "adaptive" }`, `{ type: "enabled", budgetTokens: N }`, `{ type: "disabled" }`)
- `effort` option for response effort level (`"low"`, `"medium"`, `"high"`, `"max"`)
- `max_output_tokens` assistant message error type

## [0.7.4] - 2026-02-07

### Added
- Configurable logging via `ClaudeAgent.logger` (module-level) and `Options#logger` (per-query)
  - `NullLogger` default for zero overhead when logging is not configured
  - `ClaudeAgent.debug!` convenience method for quick stderr debug logging
  - Backward-compatible with `CLAUDE_AGENT_DEBUG` env var
  - Log points across transport, control protocol, message parser, MCP server, query, and client

### Fixed
- `can_use_tool` callback now works without hooks or MCP servers configured
  - `PermissionResultAllow` and `PermissionResultDeny` (`Data.define` types) are now correctly recognized in `handle_can_use_tool` instead of silently falling through to allow
  - `normalize_hook_response` now handles `Data.define` return types from hook callbacks
- Allow responses without explicit `updated_input` now fall back to the original input (Python SDK parity)

### Changed
- Always use streaming mode with control protocol initialization (Python/TypeScript SDK parity)
  - Removes fragile conditional gate on hooks/MCP/can_use_tool
  - `send_initialize` handshake is now always sent in streaming mode

### Added
- Auto-set `permission_prompt_tool_name` to `"stdio"` when `can_use_tool` is configured (Python/TypeScript SDK parity)

## [0.7.3] - 2026-02-06

### Added
- `session_id` option for custom conversation UUIDs (`--session-id` CLI flag)
- `TeammateIdle` hook event with `TeammateIdleInput` (TypeScript SDK v0.2.33 parity)
- `TaskCompleted` hook event with `TaskCompletedInput` (TypeScript SDK v0.2.33 parity)

### Changed
- Updated SPEC.md to reflect full TypeScript SDK v0.2.34 parity

## [0.7.2] - 2026-02-05

### Added
- `description` field on `ToolPermissionContext` (TypeScript SDK v0.2.32 parity)
- `allow_managed_domains_only` field on `SandboxNetworkConfig`
- `initialization_result` method on `ControlProtocol` and `Client` with `InitializationResult`, `SlashCommand`, `ModelInfo`, and `AccountInfo` types

### Changed
- Updated SPEC.md to reference TypeScript SDK v0.2.32 and Python SDK v0.1.30

## [0.7.1] - 2026-02-03

### Added
- `debug` option for verbose debug logging (`--debug` CLI flag)
- `debug_file` option for writing debug logs to a file (`--debug-file` CLI flag)
- `stop_reason` field on `ResultMessage` indicating why the model stopped generating

### Changed
- Updated SPEC.md to reference TypeScript SDK v0.2.31 and Python SDK v0.1.29

## [0.7.0] - 2026-01-31

### Added
- MCP tool annotations support (`readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint`, `title`) on `MCP::Tool` and `MCP.tool` convenience method (TypeScript SDK v0.2.27 parity)
- README documentation for `UserMessageReplay`, `HookStartedMessage`, `HookProgressMessage`, `ToolUseSummaryMessage`, `FilesPersistedEvent` message types
- README documentation for `mcp_reconnect` and `mcp_toggle` client methods
- README documentation for MCP tool annotations

### Changed
- Updated SPEC.md to reference TypeScript SDK v0.2.27 and Python SDK v0.1.26

## [0.6.0] - 2026-01-30

### Added
- `FilesPersistedEvent` message type for file persistence confirmation (TypeScript SDK v0.2.25 parity)
- `claudeai-proxy` MCP server type support via Hash-based config passthrough

### Changed
- Updated SPEC.md to reference TypeScript SDK v0.2.25 and Python SDK v0.1.25

## [0.5.0] - 2026-01-25

### Added
- `HookStartedMessage` for hook lifecycle visibility
- `HookProgressMessage` for hook progress updates
- `ToolUseSummaryMessage` for tool use summaries
- `mcp_reconnect` and `mcp_toggle` control methods for MCP server lifecycle management
- `hook_id`, `output`, and `outcome` fields on `HookResponseMessage`
- Helper methods on `HookResponseMessage`: `success?`, `error?`, `cancelled?`

## [0.4.3] - 2026-01-18

### Changed
- Updated release workflow to use trusted publisher

## [0.4.2] - 2026-01-18

### Fixed
- Release script now uses `bundle install` (Bundler 4.x compatibility)

### Changed
- Release script prompts for RubyGems OTP upfront
- Release script creates GitHub releases automatically

## [0.4.1] - 2026-01-18

### Changed
- Simplified release script to match Kamal's approach

## [0.4.0] - 2026-01-18

### Added
- `TaskNotificationMessage` for background task completion notifications
- `Setup` hook event with `SetupInput` for init/maintenance triggers
- `skills` and `max_turns` fields in `AgentDefinition` (TypeScript SDK v0.2.12 parity)
- `init`, `init_only`, `maintenance` options for running Setup hooks
- `ClaudeAgent.run_setup` convenience method for CI/CD pipelines
- Hook-specific output fields documentation (`additionalContext`, `permissionDecision`, `updatedMCPToolOutput`, etc.)
- Document `settings` option accepts JSON strings (for plansDirectory, etc.)

## [0.3.0] - 2026-01-16

### Added
- `agent` option for specifying main thread agent name (TypeScript SDK v0.2.9 parity)
- `model` field in `SessionStartInput` hook input

## [0.2.0] - 2026-01-11

### Added
- V2 Session API for multi-turn conversations (`unstable_v2_create_session`, `unstable_v2_resume_session`, `unstable_v2_prompt`)
- `Session` class for stateful conversation management
- `SessionOptions` data type for V2 API configuration

### Fixed
- `Options#initialize` now correctly handles nil values without overriding defaults

## [0.1.0] - 2026-01-10

### Added
- MVP implementation of the Claude Agent SDK for Ruby
