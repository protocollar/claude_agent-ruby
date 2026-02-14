# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
