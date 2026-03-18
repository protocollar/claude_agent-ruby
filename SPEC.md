# Claude Agent SDK Specification

This document provides a comprehensive specification of the Claude Agent SDK, comparing feature parity across the official TypeScript and Python SDKs with this Ruby implementation.

**Reference Versions:**
- TypeScript SDK: v0.2.77 (npm package)
- Python SDK: from GitHub (commit 971994c)
- Ruby SDK: This repository

**Last Updated:** 2026-03-17

---

## Table of Contents

1. [Options/Configuration](#1-optionsconfiguration)
2. [Message Types](#2-message-types)
3. [Content Blocks](#3-content-blocks)
4. [Control Protocol](#4-control-protocol)
5. [Hooks](#5-hooks)
6. [Permissions](#6-permissions)
7. [MCP Support](#7-mcp-support)
8. [Sessions](#8-sessions)
9. [Subagents](#9-subagents)
10. [Sandbox Settings](#10-sandbox-settings)
11. [Error Handling](#11-error-handling)
12. [Client API](#12-client-api)

---

## 1. Options/Configuration

Configuration options for SDK queries and clients.

| Option                            | TypeScript | Python | Ruby | Notes                                                        |
|-----------------------------------|:----------:|:------:|:----:|--------------------------------------------------------------|
| `model`                           |     ✅      |   ✅    |  ✅   | Claude model identifier                                      |
| `fallbackModel`                   |     ✅      |   ✅    |  ✅   | Fallback if primary fails                                    |
| `systemPrompt`                    |     ✅      |   ✅    |  ✅   | String or preset object                                      |
| `appendSystemPrompt`              |     ✅      |   ✅    |  ✅   | Append to system prompt (via preset)                         |
| `tools`                           |     ✅      |   ✅    |  ✅   | Array or preset                                              |
| `allowedTools`                    |     ✅      |   ✅    |  ✅   | Auto-allowed tools                                           |
| `disallowedTools`                 |     ✅      |   ✅    |  ✅   | Blocked tools                                                |
| `permissionMode`                  |     ✅      |   ✅    |  ✅   | default/acceptEdits/plan/bypassPermissions/dontAsk           |
| `allowDangerouslySkipPermissions` |     ✅      |   ❌    |  ✅   | Required for bypassPermissions                               |
| `canUseTool`                      |     ✅      |   ✅    |  ✅   | Permission callback                                          |
| `permissionPromptToolName`        |     ✅      |   ✅    |  ✅   | MCP tool for permission prompts                              |
| `maxTurns`                        |     ✅      |   ✅    |  ✅   | Max conversation turns                                       |
| `maxBudgetUsd`                    |     ✅      |   ✅    |  ✅   | Max USD budget                                               |
| `thinking`                        |     ✅      |   ✅    |  ✅   | Thinking mode config (adaptive/enabled/disabled) (v0.2.35+)  |
| `effort`                          |     ✅      |   ✅    |  ✅   | Response effort level (low/medium/high/max) (v0.2.35+)       |
| `maxThinkingTokens`               |     ✅      |   ✅    |  ✅   | Max thinking tokens (deprecated in TS, use `thinking`)       |
| `continue`                        |     ✅      |   ✅    |  ✅   | Continue most recent conversation                            |
| `resume`                          |     ✅      |   ✅    |  ✅   | Resume session by ID                                         |
| `sessionId`                       |     ✅      |   ❌    |  ✅   | Custom UUID for conversations (v0.2.33)                      |
| `resumeSessionAt`                 |     ✅      |   ❌    |  ✅   | Resume to specific message UUID                              |
| `forkSession`                     |     ✅      |   ✅    |  ✅   | Fork on resume                                               |
| `persistSession`                  |     ✅      |   ❌    |  ✅   | Whether to persist to disk                                   |
| `enableFileCheckpointing`         |     ✅      |   ✅    |  ✅   | Track file changes for rewind                                |
| `includePartialMessages`          |     ✅      |   ✅    |  ✅   | Include stream events                                        |
| `outputFormat`                    |     ✅      |   ✅    |  ✅   | JSON schema for structured output                            |
| `mcpServers`                      |     ✅      |   ✅    |  ✅   | MCP server configurations                                    |
| `strictMcpConfig`                 |     ✅      |   ❌    |  ✅   | Strict validation of MCP config                              |
| `hooks`                           |     ✅      |   ✅    |  ✅   | Hook callbacks                                               |
| `agents`                          |     ✅      |   ✅    |  ✅   | Custom subagent definitions                                  |
| `agent`                           |     ✅      |   ❌    |  ✅   | Agent name for main thread                                   |
| `cwd`                             |     ✅      |   ✅    |  ✅   | Working directory                                            |
| `additionalDirectories`           |     ✅      |   ✅    |  ✅   | Extra allowed directories                                    |
| `env`                             |     ✅      |   ✅    |  ✅   | Environment variables                                        |
| `sandbox`                         |     ✅      |   ✅    |  ✅   | Sandbox settings                                             |
| `settingSources`                  |     ✅      |   ✅    |  ✅   | Which settings to load                                       |
| `settings`                        |     ✅      |   ✅    |  ✅   | Additional settings (path or object)                         |
| `plugins`                         |     ✅      |   ✅    |  ✅   | Plugin configurations                                        |
| `betas`                           |     ✅      |   ✅    |  ✅   | Beta features (e.g., context-1m-2025-08-07)                  |
| `abortController`                 |     ✅      |   ❌    |  ✅   | Cancellation controller                                      |
| `stderr`                          |     ✅      |   ✅    |  ✅   | Stderr callback                                              |
| `spawnClaudeCodeProcess`          |     ✅      |   ❌    |  ✅   | Custom spawn function                                        |
| `pathToClaudeCodeExecutable`      |     ✅      |   ✅    |  ✅   | Custom CLI path                                              |
| `executable`                      |     ✅      |  N/A   | N/A  | JS runtime (node/bun/deno) - JS-specific                     |
| `executableArgs`                  |     ✅      |  N/A   | N/A  | JS runtime args - JS-specific                                |
| `extraArgs`                       |     ✅      |   ✅    |  ✅   | Extra CLI arguments                                          |
| `promptSuggestions`               |     ✅      |   ❌    |  ✅   | Enable prompt suggestion after each turn (v0.2.47)           |
| `debug`                           |     ✅      |   ❌    |  ✅   | Enable verbose debug logging                                 |
| `debugFile`                       |     ✅      |   ❌    |  ✅   | Write debug logs to specific file path                       |
| `toolConfig`                      |     ✅      |   ❌    |  ✅   | Tool behavior config (e.g., askUserQuestion preview format)  |
| `onElicitation`                   |     ✅      |   ❌    |  ✅   | MCP elicitation request handler callback                     |
| `agentProgressSummaries`          |     ✅      |   ❌    |  ✅   | Progress summaries for subagents (v0.2.72)                   |

---

## 2. Message Types

Messages exchanged between SDK and CLI.

| Message Type                 | TypeScript | Python | Ruby | Notes                              |
|------------------------------|:----------:|:------:|:----:|------------------------------------|
| `UserMessage`                |     ✅      |   ✅    |  ✅   | User input                         |
| `UserMessageReplay`          |     ✅      |   ❌    |  ✅   | Replayed user message on resume    |
| `AssistantMessage`           |     ✅      |   ✅    |  ✅   | Claude response                    |
| `SystemMessage`              |     ✅      |   ✅    |  ✅   | System/init messages               |
| `ResultMessage`              |     ✅      |   ✅    |  ✅   | Final result with usage            |
| `StreamEvent`                |     ✅      |   ✅    |  ✅   | Partial streaming events           |
| `CompactBoundaryMessage`     |     ✅      |   ❌    |  ✅   | Conversation compaction marker     |
| `StatusMessage`              |     ✅      |   ❌    |  ✅   | Status updates (compacting)        |
| `ToolProgressMessage`        |     ✅      |   ❌    |  ✅   | Long-running tool progress         |
| `HookStartedMessage`         |     ✅      |   ❌    |  ✅   | Hook execution started             |
| `HookProgressMessage`        |     ✅      |   ❌    |  ✅   | Hook progress during execution     |
| `HookResponseMessage`        |     ✅      |   ❌    |  ✅   | Hook execution output              |
| `AuthStatusMessage`          |     ✅      |   ❌    |  ✅   | Authentication status              |
| `TaskNotificationMessage`    |     ✅      |   ✅    |  ✅   | Background task completion         |
| `ToolUseSummaryMessage`      |     ✅      |   ❌    |  ✅   | Summary of tool use (collapsed)    |
| `TaskStartedMessage`         |     ✅      |   ✅    |  ✅   | Subagent task registered (v0.2.45) |
| `TaskProgressMessage`        |     ✅      |   ✅    |  ✅   | Background task progress (v0.2.51) |
| `RateLimitEvent`             |     ✅      |   ✅    |  ✅   | Rate limit status changes          |
| `PromptSuggestionMessage`    |     ✅      |   ❌    |  ✅   | Suggested next prompt (v0.2.47)    |
| `FilesPersistedEvent`        |     ✅      |   ❌    |  ✅   | File persistence confirmation      |
| `ElicitationCompleteMessage` |     ✅      |   ❌    |  ✅   | MCP elicitation completed          |
| `LocalCommandOutputMessage`  |     ✅      |   ❌    |  ✅   | Local command output               |
| `APIRetryMessage`            |     ✅      |   ❌    |  ✅   | API retry notification (v0.2.77)   |

### Message Fields

#### APIRetryMessage

| Field             | TypeScript | Python | Ruby | Notes                                    |
|-------------------|:----------:|:------:|:----:|------------------------------------------|
| `attempt`         |     ✅      |   ❌    |  ✅   | Current retry attempt number             |
| `max_retries`     |     ✅      |   ❌    |  ✅   | Maximum retry count                      |
| `retry_delay_ms`  |     ✅      |   ❌    |  ✅   | Delay before retry in milliseconds       |
| `error_status`    |     ✅      |   ❌    |  ✅   | HTTP status code (null for conn errors)  |
| `error`           |     ✅      |   ❌    |  ✅   | Error type (AssistantMessageError)       |

#### ResultMessage

| Field                | TypeScript | Python | Ruby | Notes                    |
|----------------------|:----------:|:------:|:----:|--------------------------|
| `subtype`            |     ✅      |   ✅    |  ✅   | success/error_*          |
| `duration_ms`        |     ✅      |   ✅    |  ✅   | Total duration           |
| `duration_api_ms`    |     ✅      |   ✅    |  ✅   | API call duration        |
| `is_error`           |     ✅      |   ✅    |  ✅   | Error flag               |
| `num_turns`          |     ✅      |   ✅    |  ✅   | Turn count               |
| `result`             |     ✅      |   ✅    |  ✅   | Text result (on success) |
| `total_cost_usd`     |     ✅      |   ✅    |  ✅   | Total cost               |
| `usage`              |     ✅      |   ✅    |  ✅   | Token usage              |
| `modelUsage`         |     ✅      |   ❌    |  ✅   | Per-model usage          |
| `permission_denials` |     ✅      |   ❌    |  ✅   | Denied permissions       |
| `structured_output`  |     ✅      |   ✅    |  ✅   | JSON schema output       |
| `errors`             |     ✅      |   ❌    |  ✅   | Error messages           |
| `uuid`               |     ✅      |   ❌    |  ✅   | Message UUID             |
| `session_id`         |     ✅      |   ✅    |  ✅   | Session ID               |
| `stop_reason`        |     ✅      |   ✅    |  ✅   | Why model stopped        |
| `fast_mode_state`    |     ✅      |   ❌    |  ✅   | Fast mode status         |

#### Result Subtypes

| Subtype                               | TypeScript | Python | Ruby | Notes                              |
|---------------------------------------|:----------:|:------:|:----:|------------------------------------|
| `success`                             |     ✅      |   ✅    |  ✅   | Successful completion              |
| `error_during_execution`              |     ✅      |   ✅    |  ✅   | Runtime error                      |
| `error_max_turns`                     |     ✅      |   ✅    |  ✅   | Max turns exceeded                 |
| `error_max_budget_usd`                |     ✅      |   ✅    |  ✅   | Budget exceeded                    |
| `error_max_structured_output_retries` |     ✅      |   ❌    |  ✅   | Structured output retries exceeded |

#### TaskNotificationMessage

| Field         | TypeScript | Python | Ruby | Notes                       |
|---------------|:----------:|:------:|:----:|-----------------------------|
| `task_id`     |     ✅      |   ✅    |  ✅   | Task identifier             |
| `tool_use_id` |     ✅      |   ✅    |  ✅   | Correlating tool call ID    |
| `status`      |     ✅      |   ✅    |  ✅   | completed/failed/stopped    |
| `output_file` |     ✅      |   ✅    |  ✅   | Path to task output         |
| `summary`     |     ✅      |   ✅    |  ✅   | Task summary                |
| `usage`       |     ✅      |   ✅    |  ✅   | Tokens/tool counts/duration |

#### ToolProgressMessage

| Field                  | TypeScript | Python | Ruby | Notes                   |
|------------------------|:----------:|:------:|:----:|-------------------------|
| `tool_use_id`          |     ✅      |   ❌    |  ✅   | Tool use ID             |
| `tool_name`            |     ✅      |   ❌    |  ✅   | Tool name               |
| `parent_tool_use_id`   |     ✅      |   ❌    |  ✅   | Parent tool use ID      |
| `elapsed_time_seconds` |     ✅      |   ❌    |  ✅   | Elapsed time            |
| `task_id`              |     ✅      |   ❌    |  ✅   | Associated task ID      |

#### StatusMessage

| Field            | TypeScript | Python | Ruby | Notes                   |
|------------------|:----------:|:------:|:----:|-------------------------|
| `status`         |     ✅      |   ❌    |  ✅   | Current status          |
| `permissionMode` |     ✅      |   ❌    |  ✅   | Current permission mode |

#### HookResponseMessage Fields

| Field        | TypeScript | Python | Ruby | Notes                                    |
|--------------|:----------:|:------:|:----:|------------------------------------------|
| `uuid`       |     ✅      |   ❌    |  ✅   | Message UUID                             |
| `session_id` |     ✅      |   ❌    |  ✅   | Session ID                               |
| `hook_id`    |     ✅      |   ❌    |  ✅   | Unique hook execution ID                 |
| `hook_name`  |     ✅      |   ❌    |  ✅   | Hook name                                |
| `hook_event` |     ✅      |   ❌    |  ✅   | Event type (PreToolUse, PostToolUse...)  |
| `output`     |     ✅      |   ❌    |  ✅   | Combined output string                   |
| `stdout`     |     ✅      |   ❌    |  ✅   | Standard output                          |
| `stderr`     |     ✅      |   ❌    |  ✅   | Standard error                           |
| `exit_code`  |     ✅      |   ❌    |  ✅   | Hook process exit code                   |
| `outcome`    |     ✅      |   ❌    |  ✅   | 'success' / 'error' / 'cancelled'        |

#### HookProgressMessage Fields

| Field        | TypeScript | Python | Ruby | Notes                                    |
|--------------|:----------:|:------:|:----:|------------------------------------------|
| `uuid`       |     ✅      |   ❌    |  ✅   | Message UUID                             |
| `session_id` |     ✅      |   ❌    |  ✅   | Session ID                               |
| `hook_id`    |     ✅      |   ❌    |  ✅   | Unique hook execution ID                 |
| `hook_name`  |     ✅      |   ❌    |  ✅   | Hook name                                |
| `hook_event` |     ✅      |   ❌    |  ✅   | Event type                               |
| `output`     |     ✅      |   ❌    |  ✅   | Combined output so far                   |
| `stdout`     |     ✅      |   ❌    |  ✅   | Standard output so far                   |
| `stderr`     |     ✅      |   ❌    |  ✅   | Standard error so far                    |

#### TaskStartedMessage

| Field         | TypeScript | Python | Ruby | Notes                   |
|---------------|:----------:|:------:|:----:|-------------------------|
| `task_id`     |     ✅      |   ✅    |  ✅   | Task identifier         |
| `tool_use_id` |     ✅      |   ✅    |  ✅   | Correlating tool use ID |
| `description` |     ✅      |   ✅    |  ✅   | Task description        |
| `task_type`   |     ✅      |   ✅    |  ✅   | Task type (e.g., bash)  |
| `prompt`      |     ✅      |   ❌    |  ✅   | Task prompt (v0.2.75)   |

#### TaskProgressMessage

| Field            | TypeScript | Python | Ruby | Notes                                             |
|------------------|:----------:|:------:|:----:|---------------------------------------------------|
| `task_id`        |     ✅      |   ✅    |  ✅   | Task identifier                                   |
| `tool_use_id`    |     ✅      |   ✅    |  ✅   | Correlating tool use ID                           |
| `description`    |     ✅      |   ✅    |  ✅   | Current progress description                      |
| `usage`          |     ✅      |   ✅    |  ✅   | Cumulative {total_tokens, tool_uses, duration_ms} |
| `last_tool_name` |     ✅      |   ✅    |  ✅   | Last tool executed                                |
| `summary`        |     ✅      |   ❌    |  ✅   | AI-generated progress summary (v0.2.72)           |

#### AuthStatusMessage

| Field              | TypeScript | Python | Ruby | Notes                   |
|--------------------|:----------:|:------:|:----:|-------------------------|
| `isAuthenticating` |     ✅      |   ❌    |  ✅   | Authentication active   |
| `output`           |     ✅      |   ❌    |  ✅   | Auth output messages    |
| `error`            |     ✅      |   ❌    |  ✅   | Auth error message      |

#### ToolUseSummaryMessage

| Field                    | TypeScript | Python | Ruby | Notes                         |
|--------------------------|:----------:|:------:|:----:|-------------------------------|
| `summary`                |     ✅      |   ❌    |  ✅   | Summary text                  |
| `preceding_tool_use_ids` |     ✅      |   ❌    |  ✅   | Tool use IDs being summarized |

#### RateLimitEvent

| Field             | TypeScript | Python | Ruby | Notes                           |
|-------------------|:----------:|:------:|:----:|---------------------------------|
| `rate_limit_info` |     ✅      |   ✅    |  ✅   | Rate limit details object       |

Rate limit info contains: `status`, `resetsAt`, `rateLimitType`, `utilization`, `isUsingOverage`, `overageStatus`, `overageResetsAt`, `overageDisabledReason` (v0.2.49+), `surpassedThreshold`.

#### PromptSuggestionMessage

| Field        | TypeScript | Python | Ruby | Notes                   |
|--------------|:----------:|:------:|:----:|-------------------------|
| `suggestion` |     ✅      |   ❌    |  ✅   | Suggested next prompt   |

#### FilesPersistedEvent

| Field          | TypeScript | Python | Ruby | Notes                                      |
|----------------|:----------:|:------:|:----:|--------------------------------------------|
| `files`        |     ✅      |   ❌    |  ✅   | Successfully persisted {filename, file_id} |
| `failed`       |     ✅      |   ❌    |  ✅   | Failed files {filename, error}             |
| `processed_at` |     ✅      |   ❌    |  ✅   | Processing timestamp                       |

---

## 3. Content Blocks

Content block types within messages.

| Block Type              | TypeScript | Python | Ruby | Notes                   |
|-------------------------|:----------:|:------:|:----:|-------------------------|
| `TextBlock`             |     ✅      |   ✅    |  ✅   | Text content            |
| `ThinkingBlock`         |     ✅      |   ✅    |  ✅   | Extended thinking       |
| `ToolUseBlock`          |     ✅      |   ✅    |  ✅   | Tool invocation         |
| `ToolResultBlock`       |     ✅      |   ✅    |  ✅   | Tool result             |
| `ServerToolUseBlock`    |     ✅      |   ❌    |  ✅   | MCP server tool use     |
| `ServerToolResultBlock` |     ✅      |   ❌    |  ✅   | MCP server tool result  |
| `ImageContentBlock`     |     ✅      |   ❌    |  ✅   | Image data (base64/URL) |

### Block Fields

#### ToolUseBlock

| Field   | TypeScript | Python | Ruby |
|---------|:----------:|:------:|:----:|
| `id`    |     ✅      |   ✅    |  ✅   |
| `name`  |     ✅      |   ✅    |  ✅   |
| `input` |     ✅      |   ✅    |  ✅   |

#### ThinkingBlock

| Field       | TypeScript | Python | Ruby |
|-------------|:----------:|:------:|:----:|
| `thinking`  |     ✅      |   ✅    |  ✅   |
| `signature` |     ✅      |   ✅    |  ✅   |

---

## 4. Control Protocol

Bidirectional control protocol for SDK-CLI communication.

### Control Request Types

| Request Subtype           | TypeScript | Python | Ruby | Notes                                        |
|---------------------------|:----------:|:------:|:----:|----------------------------------------------|
| `initialize`              |     ✅      |   ✅    |  ✅   | Initialize session with hooks/MCP            |
| `interrupt`               |     ✅      |   ✅    |  ✅   | Interrupt current operation                  |
| `can_use_tool`            |     ✅      |   ✅    |  ✅   | Permission callback                          |
| `hook_callback`           |     ✅      |   ✅    |  ✅   | Execute hook callback                        |
| `set_permission_mode`     |     ✅      |   ✅    |  ✅   | Change permission mode                       |
| `set_model`               |     ✅      |   ✅    |  ✅   | Change model                                 |
| `set_max_thinking_tokens` |     ✅      |   ❌    |  ✅   | Change thinking tokens limit                 |
| `rewind_files`            |     ✅      |   ✅    |  ✅   | Rewind file checkpoints (supports dry_run)   |
| `mcp_message`             |     ✅      |   ✅    |  ✅   | Route MCP message                            |
| `mcp_set_servers`         |     ✅      |   ❌    |  ✅   | Dynamically set MCP servers                  |
| `mcp_status`              |     ✅      |   ✅    |  ✅   | Get MCP server status                        |
| `mcp_reconnect`           |     ✅      |   ✅    |  ✅   | Reconnect to MCP server                      |
| `mcp_toggle`              |     ✅      |   ✅    |  ✅   | Enable/disable MCP server                    |
| `stop_task`               |     ✅      |   ✅    |  ✅   | Stop a running background task               |
| `mcp_authenticate`        |     ✅      |   ❌    |  ✅   | Authenticate MCP server (v0.2.52)            |
| `mcp_clear_auth`          |     ✅      |   ❌    |  ✅   | Clear MCP server auth (v0.2.52)              |
| `supported_commands`      |     ✅      |   ❌    |  ✅   | Get available slash commands                 |
| `supported_models`        |     ✅      |   ❌    |  ✅   | Get available models                         |
| `account_info`            |     ✅      |   ❌    |  ✅   | Get account information                      |
| `apply_flag_settings`     |     ✅      |   ❌    |  ✅   | Merge settings into flag layer               |
| `supported_agents`        |     ✅      |   ❌    |  ✅   | Get available subagents (v0.2.63)            |
| `cancel_async_message`    |     ✅      |   ❌    |  ✅   | Cancel queued user message by UUID (v0.2.76) |
| `get_settings`            |     ✅      |   ❌    |  ✅   | Get effective merged settings (v0.2.72)      |

### Return Types

| Type                   | TypeScript | Python | Ruby | Notes                  |
|------------------------|:----------:|:------:|:----:|------------------------|
| `SlashCommand`         |     ✅      |   ❌    |  ✅   | Available command info |
| `ModelInfo`            |     ✅      |   ❌    |  ✅   | Model information      |
| `McpServerStatus`      |     ✅      |   ❌    |  ✅   | MCP server status      |
| `AccountInfo`          |     ✅      |   ❌    |  ✅   | Account information    |
| `InitializationResult` |     ✅      |   ❌    |  ✅   | Full init response     |
| `McpSetServersResult`  |     ✅      |   ❌    |  ✅   | Set servers result     |
| `RewindFilesResult`    |     ✅      |   ✅    |  ✅   | Rewind result          |
| `AgentInfo`            |     ✅      |   ❌    |  ✅   | Available agent info   |

#### ModelInfo Fields

| Field                      | TypeScript | Python | Ruby | Notes                                      |
|----------------------------|:----------:|:------:|:----:|--------------------------------------------|
| `value`                    |     ✅      |   ❌    |  ✅   | Model identifier                           |
| `displayName`              |     ✅      |   ❌    |  ✅   | Human-readable name                        |
| `description`              |     ✅      |   ❌    |  ✅   | Model description                          |
| `supportsEffort`           |     ✅      |   ❌    |  ✅   | Whether model supports effort              |
| `supportedEffortLevels`    |     ✅      |   ❌    |  ✅   | Available effort levels                    |
| `supportsAdaptiveThinking` |     ✅      |   ❌    |  ✅   | Whether adaptive thinking works            |
| `supportsFastMode`         |     ✅      |   ❌    |  ✅   | Whether model supports fast mode (v0.2.69) |
| `supportsAutoMode`         |     ✅      |   ❌    |  ✅   | Whether model supports auto mode (v0.2.75) |

#### McpServerStatus Fields

| Field        | TypeScript | Python | Ruby | Notes                              |
|--------------|:----------:|:------:|:----:|------------------------------------|
| `name`       |     ✅      |   ✅    |  ✅   | Server name                        |
| `status`     |     ✅      |   ✅    |  ✅   | Connection status                  |
| `serverInfo` |     ✅      |   ✅    |  ✅   | Server name/version                |
| `error`      |     ✅      |   ✅    |  ✅   | Error message (when failed)        |
| `config`     |     ✅      |   ✅    |  ✅   | Server configuration               |
| `scope`      |     ✅      |   ✅    |  ✅   | Config scope (project, user, etc.) |
| `tools`      |     ✅      |   ✅    |  ✅   | Tools with annotations             |

#### InitializationResult Fields

| Field                     | TypeScript | Python | Ruby | Notes                             |
|---------------------------|:----------:|:------:|:----:|-----------------------------------|
| `commands`                |     ✅      |   ❌    |  ✅   | Available slash commands          |
| `output_style`            |     ✅      |   ❌    |  ✅   | Current output style              |
| `available_output_styles` |     ✅      |   ❌    |  ✅   | All available output styles       |
| `models`                  |     ✅      |   ❌    |  ✅   | Available models (ModelInfo[])    |
| `account`                 |     ✅      |   ❌    |  ✅   | Account information (AccountInfo) |
| `agents`                  |     ✅      |   ❌    |  ✅   | Available agents (AgentInfo[])    |
| `fast_mode_state`         |     ✅      |   ❌    |  ✅   | Fast mode status (v0.2.75)        |

#### RewindFilesResult Fields

| Field          | TypeScript | Python | Ruby | Notes                         |
|----------------|:----------:|:------:|:----:|-------------------------------|
| `canRewind`    |     ✅      |   ✅    |  ✅   | Whether rewind is possible    |
| `error`        |     ✅      |   ❌    |  ✅   | Error message if can't rewind |
| `filesChanged` |     ✅      |   ❌    |  ✅   | List of changed file paths    |
| `insertions`   |     ✅      |   ❌    |  ✅   | Number of line insertions     |
| `deletions`    |     ✅      |   ❌    |  ✅   | Number of line deletions      |

#### McpSetServersResult Fields

| Field     | TypeScript | Python | Ruby | Notes                             |
|-----------|:----------:|:------:|:----:|-----------------------------------|
| `added`   |     ✅      |   ❌    |  ✅   | Server names that were added      |
| `removed` |     ✅      |   ❌    |  ✅   | Server names that were removed    |
| `errors`  |     ✅      |   ❌    |  ✅   | Map of server name to error       |

#### AgentInfo Fields

| Field         | TypeScript | Python | Ruby | Notes                              |
|---------------|:----------:|:------:|:----:|------------------------------------|
| `name`        |     ✅      |   ❌    |  ✅   | Agent type identifier              |
| `description` |     ✅      |   ❌    |  ✅   | When to use this agent             |
| `model`       |     ✅      |   ❌    |  ✅   | Model alias (inherits if omitted)  |

---

## 5. Hooks

Event hooks for intercepting and modifying SDK behavior.

### Hook Events

| Event                | TypeScript | Python | Ruby | Notes                             |
|----------------------|:----------:|:------:|:----:|-----------------------------------|
| `PreToolUse`         |     ✅      |   ✅    |  ✅   | Before tool execution             |
| `PostToolUse`        |     ✅      |   ✅    |  ✅   | After tool execution              |
| `PostToolUseFailure` |     ✅      |   ✅    |  ✅   | After tool failure (Py v0.1.26)   |
| `Notification`       |     ✅      |   ✅    |  ✅   | System notifications (Py v0.1.29) |
| `UserPromptSubmit`   |     ✅      |   ✅    |  ✅   | User message submitted            |
| `SessionStart`       |     ✅      |   ✅    |  ✅   | Session starts                    |
| `SessionEnd`         |     ✅      |   ❌    |  ✅   | Session ends                      |
| `Stop`               |     ✅      |   ✅    |  ✅   | Agent stops                       |
| `SubagentStart`      |     ✅      |   ✅    |  ✅   | Subagent starts (Py v0.1.29)      |
| `SubagentStop`       |     ✅      |   ✅    |  ✅   | Subagent stops                    |
| `PreCompact`         |     ✅      |   ✅    |  ✅   | Before compaction                 |
| `PostCompact`        |     ✅      |   ❌    |  ✅   | After compaction (v0.2.76)        |
| `PermissionRequest`  |     ✅      |   ✅    |  ✅   | Permission requested (Py v0.1.29) |
| `Setup`              |     ✅      |   ❌    |  ✅   | Initial setup/maintenance         |
| `TeammateIdle`       |     ✅      |   ❌    |  ✅   | Teammate idle (v0.2.33)           |
| `TaskCompleted`      |     ✅      |   ❌    |  ✅   | Task completed (v0.2.33)          |
| `Elicitation`        |     ✅      |   ❌    |  ✅   | MCP elicitation request           |
| `ElicitationResult`  |     ✅      |   ❌    |  ✅   | MCP elicitation response          |
| `ConfigChange`       |     ✅      |   ❌    |  ✅   | Config file changed (v0.2.49)     |
| `WorktreeCreate`     |     ✅      |   ❌    |  ✅   | Worktree creation (v0.2.50)       |
| `WorktreeRemove`     |     ✅      |   ❌    |  ✅   | Worktree removal (v0.2.50)        |
| `InstructionsLoaded` |     ✅      |   ❌    |  ✅   | CLAUDE.md file loaded (v0.2.69)   |

### Hook Input Types

| Input Type                    | TypeScript | Python | Ruby |
|-------------------------------|:----------:|:------:|:----:|
| `PreToolUseHookInput`         |     ✅      |   ✅    |  ✅   |
| `PostToolUseHookInput`        |     ✅      |   ✅    |  ✅   |
| `PostToolUseFailureHookInput` |     ✅      |   ✅    |  ✅   |
| `NotificationHookInput`       |     ✅      |   ✅    |  ✅   |
| `UserPromptSubmitHookInput`   |     ✅      |   ✅    |  ✅   |
| `SessionStartHookInput`       |     ✅      |   ❌    |  ✅   |
| `SessionEndHookInput`         |     ✅      |   ❌    |  ✅   |
| `StopHookInput`               |     ✅      |   ✅    |  ✅   |
| `SubagentStartHookInput`      |     ✅      |   ✅    |  ✅   |
| `SubagentStopHookInput`       |     ✅      |   ✅    |  ✅   |
| `PreCompactHookInput`         |     ✅      |   ✅    |  ✅   |
| `PostCompactHookInput`        |     ✅      |   ❌    |  ✅   |
| `PermissionRequestHookInput`  |     ✅      |   ✅    |  ✅   |
| `SetupHookInput`              |     ✅      |   ❌    |  ✅   |
| `TeammateIdleHookInput`       |     ✅      |   ❌    |  ✅   |
| `TaskCompletedHookInput`      |     ✅      |   ❌    |  ✅   |
| `ElicitationHookInput`        |     ✅      |   ❌    |  ✅   |
| `ElicitationResultHookInput`  |     ✅      |   ❌    |  ✅   |
| `ConfigChangeHookInput`       |     ✅      |   ❌    |  ✅   |
| `WorktreeCreateHookInput`     |     ✅      |   ❌    |  ✅   |
| `WorktreeRemoveHookInput`     |     ✅      |   ❌    |  ✅   |
| `InstructionsLoadedHookInput` |     ✅      |   ❌    |  ✅   |

#### BaseHookInput Fields

| Field             | TypeScript | Python | Ruby | Notes                                            |
|-------------------|:----------:|:------:|:----:|--------------------------------------------------|
| `session_id`      |     ✅      |   ✅    |  ✅   | Session identifier                               |
| `transcript_path` |     ✅      |   ✅    |  ✅   | Path to session transcript                       |
| `cwd`             |     ✅      |   ✅    |  ✅   | Working directory                                |
| `permission_mode` |     ✅      |   ❌    |  ✅   | Current permission mode                          |
| `agent_id`        |     ✅      |   ✅    |  ✅   | Subagent ID (when in subagent context) (v0.2.69) |
| `agent_type`      |     ✅      |   ✅    |  ✅   | Agent type name (v0.2.69)                        |

#### StopHookInput Fields

| Field                    | TypeScript | Python | Ruby | Notes                                  |
|--------------------------|:----------:|:------:|:----:|----------------------------------------|
| `stop_hook_active`       |     ✅      |   ✅    |  ✅   | Whether stop hook is active            |
| `last_assistant_message` |     ✅      |   ❌    |  ✅   | Last assistant message text (v0.2.51+) |

#### SubagentStopHookInput Fields

| Field                    | TypeScript | Python | Ruby | Notes                                  |
|--------------------------|:----------:|:------:|:----:|----------------------------------------|
| `stop_hook_active`       |     ✅      |   ✅    |  ✅   | Whether stop hook is active            |
| `agent_id`               |     ✅      |   ✅    |  ✅   | Subagent identifier                    |
| `agent_transcript_path`  |     ✅      |   ✅    |  ✅   | Path to agent transcript               |
| `agent_type`             |     ✅      |   ✅    |  ✅   | Agent type                             |
| `last_assistant_message` |     ✅      |   ❌    |  ✅   | Last assistant message text (v0.2.51+) |

### Hook Output Types

| Output Field         | TypeScript | Python | Ruby | Notes                 |
|----------------------|:----------:|:------:|:----:|-----------------------|
| `continue`           |     ✅      |   ✅    |  ✅   | Continue execution    |
| `async`              |     ✅      |   ✅    |  ✅   | Async hook execution  |
| `asyncTimeout`       |     ✅      |   ✅    |  ✅   | Async timeout         |
| `suppressOutput`     |     ✅      |   ✅    |  ✅   | Hide stdout           |
| `stopReason`         |     ✅      |   ✅    |  ✅   | Stop message          |
| `decision`           |     ✅      |   ✅    |  ✅   | Block decision        |
| `systemMessage`      |     ✅      |   ✅    |  ✅   | System message        |
| `reason`             |     ✅      |   ✅    |  ✅   | Reason feedback       |
| `hookSpecificOutput` |     ✅      |   ✅    |  ✅   | Event-specific output |

### Hook-Specific Output Fields

Event-specific fields returned via `hookSpecificOutput`:

#### PreToolUseHookSpecificOutput

| Field                      | TypeScript | Python | Ruby | Notes                              |
|----------------------------|:----------:|:------:|:----:|------------------------------------|
| `permissionDecision`       |     ✅      |   ✅    |  ✅   | `allow`, `deny`, or `ask`          |
| `permissionDecisionReason` |     ✅      |   ✅    |  ✅   | Reason for permission decision     |
| `updatedInput`             |     ✅      |   ✅    |  ✅   | Modified tool input                |
| `additionalContext`        |     ✅      |   ✅    |  ✅   | Context string returned to model   |

#### PostToolUseHookSpecificOutput

| Field                  | TypeScript | Python | Ruby | Notes                            |
|------------------------|:----------:|:------:|:----:|----------------------------------|
| `additionalContext`    |     ✅      |   ✅    |  ✅   | Context string returned to model |
| `updatedMCPToolOutput` |     ✅      |   ✅    |  ✅   | Modified MCP tool output         |

#### PostToolUseFailureHookSpecificOutput

| Field               | TypeScript | Python | Ruby | Notes                            |
|---------------------|:----------:|:------:|:----:|----------------------------------|
| `additionalContext` |     ✅      |   ✅    |  ✅   | Context string returned to model |

#### SessionStartHookSpecificOutput

| Field               | TypeScript | Python | Ruby | Notes                            |
|---------------------|:----------:|:------:|:----:|----------------------------------|
| `additionalContext` |     ✅      |   ✅    |  ✅   | Context string returned to model |

#### PostCompactHookInput Fields

| Field             | TypeScript | Python | Ruby | Notes                          |
|-------------------|:----------:|:------:|:----:|--------------------------------|
| `trigger`         |     ✅      |   ❌    |  ✅   | 'manual' or 'auto'             |
| `compact_summary` |     ✅      |   ❌    |  ✅   | Summary produced by compaction |

#### SetupHookSpecificOutput

| Field               | TypeScript | Python | Ruby | Notes                            |
|---------------------|:----------:|:------:|:----:|----------------------------------|
| `additionalContext` |     ✅      |   ❌    |  ✅   | Context string returned to model |

#### SubagentStartHookSpecificOutput

| Field               | TypeScript | Python | Ruby | Notes                            |
|---------------------|:----------:|:------:|:----:|----------------------------------|
| `additionalContext` |     ✅      |   ✅    |  ✅   | Context string returned to model |

#### UserPromptSubmitHookSpecificOutput

| Field               | TypeScript | Python | Ruby | Notes                            |
|---------------------|:----------:|:------:|:----:|----------------------------------|
| `additionalContext` |     ✅      |   ✅    |  ✅   | Context string returned to model |

#### PermissionRequestHookSpecificOutput

| Field      | TypeScript | Python | Ruby | Notes                                    |
|------------|:----------:|:------:|:----:|------------------------------------------|
| `decision` |     ✅      |   ✅    |  ✅   | `{ behavior: 'allow'/'deny', ... }` obj  |

#### NotificationHookSpecificOutput

| Field               | TypeScript | Python | Ruby | Notes                            |
|---------------------|:----------:|:------:|:----:|----------------------------------|
| `additionalContext` |     ✅      |   ✅    |  ✅   | Context string returned to model |

#### ElicitationHookSpecificOutput

| Field     | TypeScript | Python | Ruby | Notes                            |
|-----------|:----------:|:------:|:----:|----------------------------------|
| `action`  |     ✅      |   ❌    |  ✅   | accept/decline/cancel            |
| `content` |     ✅      |   ❌    |  ✅   | Response content for form mode   |

#### ElicitationResultHookSpecificOutput

| Field     | TypeScript | Python | Ruby | Notes                            |
|-----------|:----------:|:------:|:----:|----------------------------------|
| `action`  |     ✅      |   ❌    |  ✅   | accept/decline/cancel            |
| `content` |     ✅      |   ❌    |  ✅   | Response content                 |

### Hook Matcher

| Field                 | TypeScript | Python | Ruby |
|-----------------------|:----------:|:------:|:----:|
| `matcher`             |     ✅      |   ✅    |  ✅   |
| `hooks` / `callbacks` |     ✅      |   ✅    |  ✅   |
| `timeout`             |     ✅      |   ✅    |  ✅   |

---

## 6. Permissions

Permission handling and updates.

### Permission Modes

| Mode                | TypeScript | Python | Ruby | Notes              |
|---------------------|:----------:|:------:|:----:|--------------------|
| `default`           |     ✅      |   ✅    |  ✅   | Standard prompting |
| `acceptEdits`       |     ✅      |   ✅    |  ✅   | Auto-accept edits  |
| `plan`              |     ✅      |   ✅    |  ✅   | Planning mode      |
| `bypassPermissions` |     ✅      |   ✅    |  ✅   | Skip all checks    |
| `dontAsk`           |     ✅      |   ❌    |  ✅   | Never prompt       |

### Permission Result Types

| Type                    | TypeScript | Python | Ruby |
|-------------------------|:----------:|:------:|:----:|
| `PermissionResultAllow` |     ✅      |   ✅    |  ✅   |
| `PermissionResultDeny`  |     ✅      |   ✅    |  ✅   |

### Permission Result Fields

| Field                | TypeScript | Python | Ruby |
|----------------------|:----------:|:------:|:----:|
| `behavior`           |     ✅      |   ✅    |  ✅   |
| `updatedInput`       |     ✅      |   ✅    |  ✅   |
| `updatedPermissions` |     ✅      |   ✅    |  ✅   |
| `message` (deny)     |     ✅      |   ✅    |  ✅   |
| `interrupt` (deny)   |     ✅      |   ✅    |  ✅   |
| `toolUseID`          |     ✅      |   ❌    |  ✅   |

### Permission Update Types

| Update Type         | TypeScript | Python | Ruby |
|---------------------|:----------:|:------:|:----:|
| `addRules`          |     ✅      |   ✅    |  ✅   |
| `replaceRules`      |     ✅      |   ✅    |  ✅   |
| `removeRules`       |     ✅      |   ✅    |  ✅   |
| `setMode`           |     ✅      |   ✅    |  ✅   |
| `addDirectories`    |     ✅      |   ✅    |  ✅   |
| `removeDirectories` |     ✅      |   ✅    |  ✅   |

### Permission Update Destinations

| Destination       | TypeScript | Python | Ruby |
|-------------------|:----------:|:------:|:----:|
| `userSettings`    |     ✅      |   ✅    |  ✅   |
| `projectSettings` |     ✅      |   ✅    |  ✅   |
| `localSettings`   |     ✅      |   ✅    |  ✅   |
| `session`         |     ✅      |   ✅    |  ✅   |
| `cliArg`          |     ✅      |   ❌    |  ✅   |

### ToolPermissionContext

| Field            | TypeScript | Python | Ruby | Notes                                            |
|------------------|:----------:|:------:|:----:|--------------------------------------------------|
| `signal`         |     ✅      |   ✅    |  ✅   | Abort signal                                     |
| `suggestions`    |     ✅      |   ✅    |  ✅   | Permission suggestions                           |
| `blockedPath`    |     ✅      |   ❌    |  ✅   | Blocked file path                                |
| `decisionReason` |     ✅      |   ❌    |  ✅   | Why permission triggered                         |
| `toolUseID`      |     ✅      |   ❌    |  ✅   | Tool call ID                                     |
| `agentID`        |     ✅      |   ❌    |  ✅   | Subagent ID if applicable                        |
| `description`    |     ✅      |   ❌    |  ✅   | Human-readable tool description (v0.2.75)        |
| `title`          |     ✅      |   ❌    |  ✅   | Full permission prompt sentence (v0.2.77)        |
| `displayName`    |     ✅      |   ❌    |  ✅   | Short noun phrase for tool action (v0.2.77)      |

---

## 7. MCP Support

Model Context Protocol server support.

### MCP Server Types

| Type             | TypeScript | Python | Ruby | Notes                            |
|------------------|:----------:|:------:|:----:|----------------------------------|
| `stdio`          |     ✅      |   ✅    |  ✅   | Subprocess with stdio            |
| `sse`            |     ✅      |   ✅    |  ✅   | Server-sent events               |
| `http`           |     ✅      |   ✅    |  ✅   | HTTP transport                   |
| `sdk`            |     ✅      |   ✅    |  ✅   | In-process SDK server            |
| `claudeai-proxy` |     ✅      |   ❌    |  ✅   | Claude.ai proxy server (managed) |

### MCP Server Config Fields

#### stdio

| Field     | TypeScript | Python | Ruby |
|-----------|:----------:|:------:|:----:|
| `type`    |     ✅      |   ✅    |  ✅   |
| `command` |     ✅      |   ✅    |  ✅   |
| `args`    |     ✅      |   ✅    |  ✅   |
| `env`     |     ✅      |   ✅    |  ✅   |

#### sse/http

| Field     | TypeScript | Python | Ruby |
|-----------|:----------:|:------:|:----:|
| `type`    |     ✅      |   ✅    |  ✅   |
| `url`     |     ✅      |   ✅    |  ✅   |
| `headers` |     ✅      |   ✅    |  ✅   |

#### sdk

| Field      | TypeScript | Python | Ruby |
|------------|:----------:|:------:|:----:|
| `type`     |     ✅      |   ✅    |  ✅   |
| `name`     |     ✅      |   ✅    |  ✅   |
| `instance` |     ✅      |   ✅    |  ✅   |

#### claudeai-proxy

| Field  | TypeScript | Python | Ruby |
|--------|:----------:|:------:|:----:|
| `type` |     ✅      |   ❌    |  ✅   |
| `url`  |     ✅      |   ❌    |  ✅   |
| `id`   |     ✅      |   ❌    |  ✅   |

### SDK MCP Server

| Feature              | TypeScript | Python |         Ruby         | Notes                    |
|----------------------|:----------:|:------:|:--------------------:|--------------------------|
| `createSdkMcpServer` |     ✅      |   ✅    |          ✅           | Create SDK server        |
| `tool()` helper      |     ✅      |   ✅    |          ✅           | Create tool definition   |
| Tool input schema    |  ✅ (Zod)   |   ✅    | ✅ (Hash/JSON Schema) | Schema definition        |
| Tool annotations     |     ✅      |   ✅    |          ✅           | MCP tool hints (v0.2.27) |

---

## 8. Sessions

Session management and resumption.

| Feature              | TypeScript | Python | Ruby | Notes                   |
|----------------------|:----------:|:------:|:----:|-------------------------|
| Session ID tracking  |     ✅      |   ✅    |  ✅   | Via messages            |
| Resume by ID         |     ✅      |   ✅    |  ✅   | `resume` option         |
| Resume at message    |     ✅      |   ❌    |  ✅   | `resumeSessionAt`       |
| Fork session         |     ✅      |   ✅    |  ✅   | `forkSession` option    |
| Persist session      |     ✅      |   ❌    |  ✅   | `persistSession` option |
| Continue most recent |     ✅      |   ✅    |  ✅   | `continue` option       |

### Session Discovery

| Feature                | TypeScript | Python | Ruby | Notes                                            |
|------------------------|:----------:|:------:|:----:|--------------------------------------------------|
| `listSessions()`       |     ✅      |   ✅    |  ✅   | List past sessions with metadata (v0.2.53)       |
| `getSessionMessages()` |     ✅      |   ✅    |  ✅   | Read session transcript messages (v0.2.59)       |
| `getSessionInfo()`     |     ✅      |   ❌    |  ✅   | Get single session metadata (v0.2.75)            |
| `renameSession()`      |     ✅      |   ✅    |  ✅   | Rename a session (v0.2.74)                       |
| `tagSession()`         |     ✅      |   ✅    |  ✅   | Tag a session (v0.2.75)                          |
| `forkSession()`        |     ✅      |   ❌    |  ✅   | Fork/branch a session (v0.2.76)                  |

#### ListSessionsOptions

| Field              | TypeScript | Python | Ruby | Notes                                         |
|--------------------|:----------:|:------:|:----:|-----------------------------------------------|
| `dir`              |     ✅      |   ✅    |  ✅   | Project directory (includes worktrees)        |
| `limit`            |     ✅      |   ✅    |  ✅   | Maximum number of sessions to return          |
| `includeWorktrees` |     ✅      |   ✅    |  ✅   | Include git worktree sessions (default: true) |
| `offset`           |     ✅      |   ❌    |  ✅   | Pagination offset (v0.2.75)                   |

#### GetSessionMessagesOptions

| Field    | TypeScript | Python | Ruby | Notes                                        |
|----------|:----------:|:------:|:----:|----------------------------------------------|
| `dir`    |     ✅      |   ✅    |  ✅   | Project directory to find session in         |
| `limit`  |     ✅      |   ✅    |  ✅   | Maximum number of messages to return         |
| `offset` |     ✅      |   ✅    |  ✅   | Number of messages to skip from the start    |

#### SessionMessage Fields

| Field                | TypeScript | Python | Ruby | Notes                            |
|----------------------|:----------:|:------:|:----:|----------------------------------|
| `type`               |     ✅      |   ✅    |  ✅   | 'user' or 'assistant'            |
| `uuid`               |     ✅      |   ✅    |  ✅   | Message UUID                     |
| `session_id`         |     ✅      |   ✅    |  ✅   | Session ID                       |
| `message`            |     ✅      |   ✅    |  ✅   | Raw message content              |
| `parent_tool_use_id` |     ✅      |   ✅    |  ✅   | Parent tool use ID (always null) |

#### SDKSessionInfo Fields

| Field          | TypeScript | Python | Ruby | Notes                               |
|----------------|:----------:|:------:|:----:|-------------------------------------|
| `sessionId`    |     ✅      |   ✅    |  ✅   | Session UUID                        |
| `summary`      |     ✅      |   ✅    |  ✅   | Display title/summary               |
| `lastModified` |     ✅      |   ✅    |  ✅   | Last modified time (ms since epoch) |
| `fileSize`     |     ✅      |   ✅    |  ✅   | Session file size in bytes          |
| `customTitle`  |     ✅      |   ✅    |  ✅   | User-set title via /rename          |
| `firstPrompt`  |     ✅      |   ✅    |  ✅   | First meaningful user prompt        |
| `gitBranch`    |     ✅      |   ✅    |  ✅   | Git branch at end of session        |
| `cwd`          |     ✅      |   ✅    |  ✅   | Working directory for session       |
| `tag`          |     ✅      |   ❌    |  ✅   | User-set tag (v0.2.75)              |
| `createdAt`    |     ✅      |   ❌    |  ✅   | Creation time in ms (v0.2.75)       |

#### ForkSessionOptions

| Field            | TypeScript | Python | Ruby | Notes                                          |
|------------------|:----------:|:------:|:----:|------------------------------------------------|
| `dir`            |     ✅      |   ❌    |  ✅   | Project directory                              |
| `upToMessageId`  |     ✅      |   ❌    |  ✅   | Slice transcript up to this UUID (inclusive)   |
| `title`          |     ✅      |   ❌    |  ✅   | Custom title for the fork                      |

#### ForkSessionResult

| Field       | TypeScript | Python | Ruby | Notes                          |
|-------------|:----------:|:------:|:----:|--------------------------------|
| `sessionId` |     ✅      |   ❌    |  ✅   | New forked session UUID        |

### V2 Session API (Unstable)

| Feature                     | TypeScript | Python | Ruby | Notes                     |
|-----------------------------|:----------:|:------:|:----:|---------------------------|
| `SDKSession` interface      |     ✅      |   ❌    |  ✅   | Multi-turn session object |
| `unstable_v2_createSession` |     ✅      |   ❌    |  ✅   | Create new session        |
| `unstable_v2_resumeSession` |     ✅      |   ❌    |  ✅   | Resume existing session   |
| `unstable_v2_prompt`        |     ✅      |   ❌    |  ✅   | One-shot prompt           |

---

## 9. Subagents

Custom subagent definitions.

### AgentDefinition

| Field                                 | TypeScript | Python | Ruby | Notes                                      |
|---------------------------------------|:----------:|:------:|:----:|--------------------------------------------|
| `description`                         |     ✅      |   ✅    |  ✅   | When to use agent                          |
| `prompt`                              |     ✅      |   ✅    |  ✅   | Agent system prompt                        |
| `tools`                               |     ✅      |   ✅    |  ✅   | Allowed tools                              |
| `disallowedTools`                     |     ✅      |   ❌    |  ✅   | Blocked tools                              |
| `model`                               |     ✅      |   ✅    |  ✅   | Model override (sonnet/opus/haiku/inherit) |
| `mcpServers`                          |     ✅      |   ✅    |  ✅   | Agent-specific MCP servers                 |
| `criticalSystemReminder_EXPERIMENTAL` |     ✅      |   ❌    |  ✅   | Critical reminder (experimental)           |
| `skills`                              |     ✅      |   ✅    |  ✅   | Skills to preload into agent context       |
| `memory`                              |     ❌      |   ✅    |  ❌   | Memory scope for agent (Python-only)       |
| `maxTurns`                            |     ✅      |   ❌    |  ✅   | Max agentic turns before stopping          |

---

## 10. Sandbox Settings

Sandbox configuration for command execution isolation.

### SandboxSettings

| Field                            | TypeScript | Python | Ruby |
|----------------------------------|:----------:|:------:|:----:|
| `enabled`                        |     ✅      |   ✅    |  ✅   |
| `autoAllowBashIfSandboxed`       |     ✅      |   ✅    |  ✅   |
| `excludedCommands`               |     ✅      |   ✅    |  ✅   |
| `allowUnsandboxedCommands`       |     ✅      |   ✅    |  ✅   |
| `network`                        |     ✅      |   ✅    |  ✅   |
| `ignoreViolations`               |     ✅      |   ✅    |  ✅   |
| `enableWeakerNestedSandbox`      |     ✅      |   ✅    |  ✅   |
| `enableWeakerNetworkIsolation`   |     ✅      |   ❌    |  ✅   |
| `ripgrep`                        |     ✅      |   ❌    |  ✅   |
| `filesystem`                     |     ✅      |   ❌    |  ✅   |

### SandboxFilesystemConfig

| Field                       | TypeScript | Python | Ruby |
|-----------------------------|:----------:|:------:|:----:|
| `allowWrite`                |     ✅      |   ❌    |  ✅   |
| `denyWrite`                 |     ✅      |   ❌    |  ✅   |
| `denyRead`                  |     ✅      |   ❌    |  ✅   |
| `allowRead`                 |     ✅      |   ❌    |  ✅   |
| `allowManagedReadPathsOnly` |     ✅      |   ❌    |  ✅   |

### SandboxNetworkConfig

| Field                     | TypeScript | Python | Ruby |
|---------------------------|:----------:|:------:|:----:|
| `allowedDomains`          |     ✅      |   ❌    |  ✅   |
| `allowManagedDomainsOnly` |     ✅      |   ❌    |  ✅   |
| `allowUnixSockets`        |     ✅      |   ✅    |  ✅   |
| `allowAllUnixSockets`     |     ✅      |   ✅    |  ✅   |
| `allowLocalBinding`       |     ✅      |   ✅    |  ✅   |
| `httpProxyPort`           |     ✅      |   ✅    |  ✅   |
| `socksProxyPort`          |     ✅      |   ✅    |  ✅   |

---

## 11. Error Handling

Error types and hierarchy.

| Error Type           | TypeScript | Python | Ruby | Notes                          |
|----------------------|:----------:|:------:|:----:|--------------------------------|
| Base Error           |     ✅      |   ✅    |  ✅   | `Error` / `ClaudeAgent::Error` |
| `AbortError`         |     ✅      |   ❌    |  ✅   | Operation cancelled            |
| `CLINotFoundError`   |     ❌      |   ✅    |  ✅   | CLI not found                  |
| `CLIVersionError`    |     ❌      |   ❌    |  ✅   | CLI version too old            |
| `CLIConnectionError` |     ❌      |   ✅    |  ✅   | Connection failed              |
| `ProcessError`       |     ❌      |   ✅    |  ✅   | CLI process failed             |
| `JSONDecodeError`    |     ❌      |   ✅    |  ✅   | JSON parsing failed            |
| `MessageParseError`  |     ❌      |   ✅    |  ✅   | Message parsing failed         |
| `TimeoutError`       |     ❌      |   ❌    |  ✅   | Control request timeout        |
| `ConfigurationError` |     ❌      |   ❌    |  ✅   | Invalid configuration          |

### Assistant Message Errors

| Error Type              | TypeScript | Python | Ruby |
|-------------------------|:----------:|:------:|:----:|
| `authentication_failed` |     ✅      |   ✅    |  ✅   |
| `billing_error`         |     ✅      |   ✅    |  ✅   |
| `rate_limit`            |     ✅      |   ✅    |  ✅   |
| `invalid_request`       |     ✅      |   ✅    |  ✅   |
| `server_error`          |     ✅      |   ✅    |  ✅   |
| `unknown`               |     ✅      |   ✅    |  ✅   |
| `max_output_tokens`     |     ✅      |   ❌    |  ✅   |

---

## 12. Client API

Public API surface for SDK clients.

### Standalone Functions

| Feature                | TypeScript | Python | Ruby | Notes                                      |
|------------------------|:----------:|:------:|:----:|--------------------------------------------|
| `listSessions()`       |     ✅      |   ✅    |  ✅   | List past sessions with metadata (v0.2.53) |
| `getSessionMessages()` |     ✅      |   ✅    |  ✅   | Read session transcript (v0.2.59)          |
| `getSessionInfo()`     |     ✅      |   ❌    |  ✅   | Get single session metadata (v0.2.75)      |
| `renameSession()`      |     ✅      |   ✅    |  ✅   | Rename a session (v0.2.74)                 |
| `tagSession()`         |     ✅      |   ✅    |  ✅   | Tag a session (v0.2.75)                    |
| `forkSession()`        |     ✅      |   ❌    |  ✅   | Fork/branch a session (v0.2.76)            |

### Query Interface

| Feature                 | TypeScript  |   Python    |          Ruby           | Notes              |
|-------------------------|:-----------:|:-----------:|:-----------------------:|--------------------|
| One-shot query function | ✅ `query()` | ✅ `query()` | ✅ `ClaudeAgent.query()` | Simple prompts     |
| Returns async generator |      ✅      |      ✅      |     ✅ (Enumerator)      | Streaming messages |

### Query Control Methods

| Method                   | TypeScript | Python | Ruby | Notes                                        |
|--------------------------|:----------:|:------:|:----:|----------------------------------------------|
| `interrupt()`            |     ✅      |   ✅    |  ✅   | Interrupt execution                          |
| `setPermissionMode()`    |     ✅      |   ✅    |  ✅   | Change permission mode                       |
| `setModel()`             |     ✅      |   ✅    |  ✅   | Change model                                 |
| `setMaxThinkingTokens()` |     ✅      |   ❌    |  ✅   | Set thinking limit                           |
| `supportedCommands()`    |     ✅      |   ❌    |  ✅   | Get slash commands                           |
| `supportedModels()`      |     ✅      |   ❌    |  ✅   | Get available models                         |
| `mcpServerStatus()`      |     ✅      |   ✅    |  ✅   | Get MCP status                               |
| `accountInfo()`          |     ✅      |   ❌    |  ✅   | Get account info                             |
| `rewindFiles()`          |     ✅      |   ✅    |  ✅   | Rewind file changes                          |
| `setMcpServers()`        |     ✅      |   ❌    |  ✅   | Dynamic MCP servers                          |
| `reconnectMcpServer()`   |     ✅      |   ✅    |  ✅   | Reconnect MCP server                         |
| `toggleMcpServer()`      |     ✅      |   ✅    |  ✅   | Enable/disable MCP                           |
| `stopTask()`             |     ✅      |   ✅    |  ✅   | Stop running task                            |
| `streamInput()`          |     ✅      |   ✅    |  ✅   | Stream user input                            |
| `initializationResult()` |     ✅      |   ✅    |  ✅   | Full init response (Py: `get_server_info()`) |
| `close()`                |     ✅      |   ✅    |  ✅   | Close query/session                          |
| `supportedAgents()`      |     ✅      |   ❌    |  ✅   | Get available subagents (v0.2.63)            |

### Client Class

| Feature              | TypeScript |       Python        |          Ruby           | Notes                                                                                                                |
|----------------------|:----------:|:-------------------:|:-----------------------:|----------------------------------------------------------------------------------------------------------------------|
| Multi-turn client    |     ❌      | ✅ `ClaudeSDKClient` | ✅ `ClaudeAgent::Client` | Interactive sessions                                                                                                 |
| `connect()`          |    N/A     |          ✅          |            ✅            | Start session                                                                                                        |
| `disconnect()`       |    N/A     |          ✅          |            ✅            | End session                                                                                                          |
| `send_message()`     |    N/A     |          ✅          |            ✅            | Send user message                                                                                                    |
| `receive_response()` |    N/A     |          ✅          |            ✅            | Receive until result                                                                                                 |
| `stream_input()`     |    N/A     |          ❌          |            ✅            | Stream input messages                                                                                                |
| `abort!()`           |    N/A     |          ❌          |            ✅            | Abort operations                                                                                                     |
| Control methods      |    N/A     |       Partial       |            ✅            | Python: interrupt, setPermissionMode, setModel, rewindFiles, mcpStatus, reconnectMcp, toggleMcp, stopTask; Ruby: all |

### Transport

| Feature               | TypeScript | Python | Ruby | Notes                    |
|-----------------------|:----------:|:------:|:----:|--------------------------|
| `Transport` interface |     ✅      |   ✅    |  ✅   | Transport abstraction    |
| Process transport     |     ✅      |   ✅    |  ✅   | Subprocess communication |
| Custom spawn          |     ✅      |   ❌    |  ✅   | VM/container support     |

---

## Legend

- ✅ = Fully implemented
- ❌ = Not implemented
- N/A = Not applicable (language-specific feature)
- Partial = Partially implemented

---

## Notes

### TypeScript SDK
- Primary reference for API surface (most comprehensive)
- Source is bundled/minified, but `sdk.d.ts` provides complete type definitions
- Includes unstable V2 session API
- `executable`/`executableArgs` are JS-specific (`node`/`bun`/`deno`)
- Does NOT have `user`, `init`/`initOnly`/`maintenance` as typed Options (use `extraArgs` or `settingSources`)
- `ApiKeySource` includes `'oauth'`
- v0.2.45: Added `TaskStartedMessage`, `RateLimitEvent` message types
- v0.2.47: Added `promptSuggestions` option and `PromptSuggestionMessage`
- v0.2.49: Added `ConfigChange` hook event, `SandboxFilesystemConfig`, ModelInfo capability fields
- v0.2.50: Added `WorktreeCreate`/`WorktreeRemove` hook events, `apply_flag_settings` control request
- v0.2.51: Added `TaskProgressMessage`, `StopHookInput.last_assistant_message`, `SubagentStopHookInput.last_assistant_message`
- v0.2.52: Added `mcp_authenticate`/`mcp_clear_auth` control requests for MCP server authentication
- v0.2.53: Added `listSessions()` for discovering and listing past sessions with `SDKSessionInfo` metadata
- v0.2.54 – v0.2.58: CLI parity updates (no new SDK-facing features)
- v0.2.59: Added `getSessionMessages()` for reading session transcript history with pagination (limit/offset)
- v0.2.61 – v0.2.62: CLI parity updates (no new SDK-facing features)
- v0.2.63: Added `supportedAgents()` method on Query, fixed `pathToClaudeCodeExecutable` PATH resolution
- v0.2.64 – v0.2.68: CLI parity updates (no new SDK-facing features)
- v0.2.69: Added `toolConfig` option (askUserQuestion preview format), `supportsFastMode` in ModelInfo, `agent_id`/`agent_type` on BaseHookInput, `InstructionsLoaded` hook event
- v0.2.70: Made `AgentToolInput.subagent_type` optional (defaults to general-purpose), fixed HTTP MCP servers
- v0.2.71: CLI parity update; `settings` now a typed Option (string path or `Settings` object)
- v0.2.72: Added `agentProgressSummaries` option for periodic AI-generated progress summaries
- v0.2.73: Fixed `options.env` being overridden by `~/.claude/settings.json`
- v0.2.74: Added `renameSession()` for renaming session files
- v0.2.75: Added `tag`/`createdAt` fields on `SDKSessionInfo`; `getSessionInfo()` for single-session lookup; `offset` on `listSessions` for pagination; `tagSession()` for tagging sessions; `supportsAutoMode` in `ModelInfo`; `description` on `SDKControlPermissionRequest`; `prompt` on `SDKTaskStartedMessage`; `fast_mode_state` on `SDKControlInitializeResponse`; `queued_to_running` status on `AgentToolOutput`
- v0.2.76: Added `forkSession(sessionId, opts?)` for branching conversations from a point; `cancel_async_message` control subtype to drop queued user messages; `PostCompact` hook event with `compact_summary` field; `get_settings` control request for reading effective merged settings; `planFilePath` field on `ExitPlanMode` tool input
- v0.2.77: Added `SDKAPIRetryMessage` (system subtype `api_retry`) exposing attempt count, max retries, delay, and error status for transient API error retries; added `title` and `displayName` fields on `SDKControlPermissionRequest`/`CanUseTool` options; added `allowRead` and `allowManagedReadPathsOnly` on `SandboxFilesystemConfig`
- Includes `Elicitation`/`ElicitationResult` hook events, `onElicitation` option, `ElicitationCompleteMessage`, `LocalCommandOutputMessage`, `FastModeState` (undocumented in changelog, present in types)

### Python SDK
- Full source available with `Transport` abstract class
- Partial control protocol: query and client support interrupt, setPermissionMode, setModel, rewindFiles, mcpStatus, reconnectMcpServer, toggleMcpServer, stopTask
- Has `CLINotFoundError`, `CLIConnectionError`, `ProcessError`, `CLIJSONDecodeError`, `MessageParseError` error types
- Has `TaskStartedMessage`, `TaskProgressMessage`, `TaskNotificationMessage` typed message classes (v0.1.46+)
- Has `stop_reason` field on ResultMessage (v0.1.46+)
- Has `SDKSessionInfo`, `SessionMessage` types with `list_sessions()`/`get_session_messages()` functions (v0.1.46+)
- Has `McpServerStatus` with all fields (name, status, serverInfo, error, config, scope, tools) (v0.1.46+)
- Has `agent_id`/`agent_type` on tool-lifecycle hook inputs (v0.1.46+)
- Has `add_mcp_server()`/`remove_mcp_server()` client methods for runtime MCP management (v0.1.46+)
- Has `include_worktrees` parameter on `list_sessions()` (v0.1.46+)
- Missing hooks: SessionEnd, Setup, TeammateIdle, TaskCompleted, Elicitation, ElicitationResult, ConfigChange, WorktreeCreate, WorktreeRemove, InstructionsLoaded
- Missing permission modes: `dontAsk`
- Missing options: `allowDangerouslySkipPermissions`, `persistSession`, `resumeSessionAt`, `sessionId`, `strictMcpConfig`, `init`/`initOnly`/`maintenance`, `debug`/`debugFile`, `promptSuggestions`, `onElicitation`, `toolConfig`, `agentProgressSummaries`, `agent` (main thread agent)
- `ToolPermissionContext` missing `blockedPath`, `decisionReason`, `toolUseID`, `agentID`, `description`
- Has `rename_session()`/`tag_session()` for session mutation
- Has `RateLimitEvent`/`RateLimitInfo` types with full field coverage
- Has SDK MCP server support with `tool()` helper and annotations
- Missing `getSessionInfo()`, `offset` on `list_sessions`, `tag`/`createdAt` on `SDKSessionInfo`
- Added `thinking` config and `effort` option in v0.1.36
- Handles `rate_limit_event` and unknown message types gracefully (v0.1.40)
- Client has `get_server_info()` for accessing the initialization result (v0.1.31+)
- v0.1.45 – v0.1.48: Major catch-up with TypeScript SDK (task messages, session APIs, MCP control methods, stop_reason)
- v0.1.48: Fixed fine-grained tool streaming regression
- Added `RateLimitEvent` message type with `RateLimitInfo`
- Added `rename_session()` and `tag_session()` session management functions
- `AgentDefinition` now has `skills`, `mcpServers`, and `memory` (Python-only) fields
- Missing: `onElicitation`, `Elicitation`/`ElicitationResult` hooks, `ElicitationCompleteMessage`, `LocalCommandOutputMessage`, `FastModeState`, `InstructionsLoaded` hook, `agentProgressSummaries`, `getSessionInfo()`, `forkSession()`, `PostCompact` hook, `cancel_async_message`, `get_settings`, `APIRetryMessage`

### Ruby SDK (This Repository)
- Feature parity with TypeScript SDK v0.2.77
- Ruby-idiomatic patterns (Data.define, snake_case)
- Complete control protocol, hook, and V2 Session API support
- Dedicated Client class for multi-turn conversations
- `executable`/`executableArgs` marked N/A (JS runtime options)
