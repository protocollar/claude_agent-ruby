# Claude Agent SDK Specification

This document provides a comprehensive specification of the Claude Agent SDK, comparing feature parity across the official TypeScript and Python SDKs with this Ruby implementation.

**Reference Versions:**
- TypeScript SDK: v0.2.56 (npm package)
- Python SDK: v0.1.43 from GitHub (commit 9d758dd)
- Ruby SDK: This repository

**Last Updated:** 2026-02-25

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
| `settings`                        |     ✅      |   ✅    |  ✅   | Settings file path or JSON string (e.g., plansDirectory)     |
| `settingSources`                  |     ✅      |   ✅    |  ✅   | Which settings to load                                       |
| `plugins`                         |     ✅      |   ✅    |  ✅   | Plugin configurations                                        |
| `betas`                           |     ✅      |   ✅    |  ✅   | Beta features (e.g., context-1m-2025-08-07)                  |
| `abortController`                 |     ✅      |   ❌    |  ✅   | Cancellation controller                                      |
| `stderr`                          |     ✅      |   ✅    |  ✅   | Stderr callback                                              |
| `spawnClaudeCodeProcess`          |     ✅      |   ❌    |  ✅   | Custom spawn function                                        |
| `pathToClaudeCodeExecutable`      |     ✅      |   ✅    |  ✅   | Custom CLI path                                              |
| `executable`                      |     ✅      |  N/A   | N/A  | JS runtime (node/bun/deno) - JS-specific                     |
| `executableArgs`                  |     ✅      |  N/A   | N/A  | JS runtime args - JS-specific                                |
| `extraArgs`                       |     ✅      |   ✅    |  ✅   | Extra CLI arguments                                          |
| `user`                            |     ✅      |   ✅    |  ✅   | User identifier (V2 Session API)                             |
| `init`                            |     ✅      |   ❌    |  ✅   | Run Setup hooks (init trigger), then continue (hidden CLI)   |
| `initOnly`                        |     ✅      |   ❌    |  ✅   | Run Setup hooks (init trigger), then exit (hidden CLI)       |
| `maintenance`                     |     ✅      |   ❌    |  ✅   | Run Setup hooks (maintenance trigger), continue (hidden CLI) |
| `promptSuggestions`               |     ✅      |   ❌    |  ✅   | Enable prompt suggestion after each turn (v0.2.47)           |
| `debug`                           |     ✅      |   ❌    |  ✅   | Enable verbose debug logging                                 |
| `debugFile`                       |     ✅      |   ❌    |  ✅   | Write debug logs to specific file path                       |

---

## 2. Message Types

Messages exchanged between SDK and CLI.

| Message Type              | TypeScript | Python | Ruby | Notes                              |
|---------------------------|:----------:|:------:|:----:|------------------------------------|
| `UserMessage`             |     ✅      |   ✅    |  ✅   | User input                         |
| `UserMessageReplay`       |     ✅      |   ❌    |  ✅   | Replayed user message on resume    |
| `AssistantMessage`        |     ✅      |   ✅    |  ✅   | Claude response                    |
| `SystemMessage`           |     ✅      |   ✅    |  ✅   | System/init messages               |
| `ResultMessage`           |     ✅      |   ✅    |  ✅   | Final result with usage            |
| `StreamEvent`             |     ✅      |   ✅    |  ✅   | Partial streaming events           |
| `CompactBoundaryMessage`  |     ✅      |   ❌    |  ✅   | Conversation compaction marker     |
| `StatusMessage`           |     ✅      |   ❌    |  ✅   | Status updates (compacting)        |
| `ToolProgressMessage`     |     ✅      |   ❌    |  ✅   | Long-running tool progress         |
| `HookStartedMessage`      |     ✅      |   ❌    |  ✅   | Hook execution started             |
| `HookProgressMessage`     |     ✅      |   ❌    |  ✅   | Hook progress during execution     |
| `HookResponseMessage`     |     ✅      |   ❌    |  ✅   | Hook execution output              |
| `AuthStatusMessage`       |     ✅      |   ❌    |  ✅   | Authentication status              |
| `TaskNotificationMessage` |     ✅      |   ❌    |  ✅   | Background task completion         |
| `ToolUseSummaryMessage`   |     ✅      |   ❌    |  ✅   | Summary of tool use (collapsed)    |
| `TaskStartedMessage`      |     ✅      |   ❌    |  ✅   | Subagent task registered (v0.2.45) |
| `TaskProgressMessage`     |     ✅      |   ❌    |  ✅   | Background task progress (v0.2.51) |
| `RateLimitEvent`          |     ✅      |   ❌    |  ✅   | Rate limit status changes          |
| `PromptSuggestionMessage` |     ✅      |   ❌    |  ✅   | Suggested next prompt (v0.2.47)    |
| `FilesPersistedEvent`     |     ✅      |   ❌    |  ✅   | File persistence confirmation      |

### Message Fields

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
| `stop_reason`        |     ✅      |   ❌    |  ✅   | Why model stopped        |

#### Result Subtypes

| Subtype                               | TypeScript | Python | Ruby | Notes                              |
|---------------------------------------|:----------:|:------:|:----:|------------------------------------|
| `success`                             |     ✅      |   ✅    |  ✅   | Successful completion              |
| `error_during_execution`              |     ✅      |   ✅    |  ✅   | Runtime error                      |
| `error_max_turns`                     |     ✅      |   ✅    |  ✅   | Max turns exceeded                 |
| `error_max_budget_usd`                |     ✅      |   ✅    |  ✅   | Budget exceeded                    |
| `error_max_structured_output_retries` |     ✅      |   ❌    |  ✅   | Structured output retries exceeded |

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

| Request Subtype           | TypeScript | Python | Ruby | Notes                             |
|---------------------------|:----------:|:------:|:----:|-----------------------------------|
| `initialize`              |     ✅      |   ✅    |  ✅   | Initialize session with hooks/MCP |
| `interrupt`               |     ✅      |   ✅    |  ✅   | Interrupt current operation       |
| `can_use_tool`            |     ✅      |   ✅    |  ✅   | Permission callback               |
| `hook_callback`           |     ✅      |   ✅    |  ✅   | Execute hook callback             |
| `set_permission_mode`     |     ✅      |   ✅    |  ✅   | Change permission mode            |
| `set_model`               |     ✅      |   ✅    |  ✅   | Change model                      |
| `set_max_thinking_tokens` |     ✅      |   ❌    |  ✅   | Change thinking tokens limit      |
| `rewind_files`            |     ✅      |   ✅    |  ✅   | Rewind file checkpoints           |
| `mcp_message`             |     ✅      |   ✅    |  ✅   | Route MCP message                 |
| `mcp_set_servers`         |     ✅      |   ❌    |  ✅   | Dynamically set MCP servers       |
| `mcp_status`              |     ✅      |   ✅    |  ✅   | Get MCP server status             |
| `mcp_reconnect`           |     ✅      |   ❌    |  ✅   | Reconnect to MCP server           |
| `mcp_toggle`              |     ✅      |   ❌    |  ✅   | Enable/disable MCP server         |
| `stop_task`               |     ✅      |   ❌    |  ✅   | Stop a running background task    |
| `mcp_authenticate`        |     ✅      |   ❌    |  ✅   | Authenticate MCP server (v0.2.52) |
| `mcp_clear_auth`          |     ✅      |   ❌    |  ✅   | Clear MCP server auth (v0.2.52)   |
| `supported_commands`      |     ✅      |   ❌    |  ✅   | Get available slash commands      |
| `supported_models`        |     ✅      |   ❌    |  ✅   | Get available models              |
| `account_info`            |     ✅      |   ❌    |  ✅   | Get account information           |
| `apply_flag_settings`     |     ✅      |   ❌    |  ✅   | Merge settings into flag layer    |

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
| `SessionStart`       |     ✅      |   ❌    |  ✅   | Session starts                    |
| `SessionEnd`         |     ✅      |   ❌    |  ✅   | Session ends                      |
| `Stop`               |     ✅      |   ✅    |  ✅   | Agent stops                       |
| `SubagentStart`      |     ✅      |   ✅    |  ✅   | Subagent starts (Py v0.1.29)      |
| `SubagentStop`       |     ✅      |   ✅    |  ✅   | Subagent stops                    |
| `PreCompact`         |     ✅      |   ✅    |  ✅   | Before compaction                 |
| `PermissionRequest`  |     ✅      |   ✅    |  ✅   | Permission requested (Py v0.1.29) |
| `Setup`              |     ✅      |   ❌    |  ✅   | Initial setup/maintenance         |
| `TeammateIdle`       |     ✅      |   ❌    |  ✅   | Teammate idle (v0.2.33)           |
| `TaskCompleted`      |     ✅      |   ❌    |  ✅   | Task completed (v0.2.33)          |
| `ConfigChange`       |     ✅      |   ❌    |  ✅   | Config file changed (v0.2.49)     |
| `WorktreeCreate`     |     ✅      |   ❌    |  ✅   | Worktree creation (v0.2.50)       |
| `WorktreeRemove`     |     ✅      |   ❌    |  ✅   | Worktree removal (v0.2.50)        |

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
| `PermissionRequestHookInput`  |     ✅      |   ✅    |  ✅   |
| `SetupHookInput`              |     ✅      |   ❌    |  ✅   |
| `TeammateIdleHookInput`       |     ✅      |   ❌    |  ✅   |
| `TaskCompletedHookInput`      |     ✅      |   ❌    |  ✅   |
| `ConfigChangeHookInput`       |     ✅      |   ❌    |  ✅   |
| `WorktreeCreateHookInput`     |     ✅      |   ❌    |  ✅   |
| `WorktreeRemoveHookInput`     |     ✅      |   ❌    |  ✅   |

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

| Field            | TypeScript | Python | Ruby | Notes                           |
|------------------|:----------:|:------:|:----:|---------------------------------|
| `signal`         |     ✅      |   ✅    |  ✅   | Abort signal                    |
| `suggestions`    |     ✅      |   ✅    |  ✅   | Permission suggestions          |
| `blockedPath`    |     ✅      |   ❌    |  ✅   | Blocked file path               |
| `decisionReason` |     ✅      |   ❌    |  ✅   | Why permission triggered        |
| `toolUseID`      |     ✅      |   ❌    |  ✅   | Tool call ID                    |
| `agentID`        |     ✅      |   ❌    |  ✅   | Subagent ID if applicable       |
| `description`    |     ✅      |   ❌    |  ✅   | Human-readable tool description |

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

| Feature          | TypeScript | Python | Ruby | Notes                                      |
|------------------|:----------:|:------:|:----:|--------------------------------------------|
| `listSessions()` |     ✅      |   ❌    |  ✅   | List past sessions with metadata (v0.2.53) |

#### SDKSessionInfo Fields

| Field          | TypeScript | Python | Ruby | Notes                               |
|----------------|:----------:|:------:|:----:|-------------------------------------|
| `sessionId`    |     ✅      |   ❌    |  ✅   | Session UUID                        |
| `summary`      |     ✅      |   ❌    |  ✅   | Display title/summary               |
| `lastModified` |     ✅      |   ❌    |  ✅   | Last modified time (ms since epoch) |
| `fileSize`     |     ✅      |   ❌    |  ✅   | Session file size in bytes          |
| `customTitle`  |     ✅      |   ❌    |  ✅   | User-set title via /rename          |
| `firstPrompt`  |     ✅      |   ❌    |  ✅   | First meaningful user prompt        |
| `gitBranch`    |     ✅      |   ❌    |  ✅   | Git branch at end of session        |
| `cwd`          |     ✅      |   ❌    |  ✅   | Working directory for session       |

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
| `mcpServers`                          |     ✅      |   ❌    |  ✅   | Agent-specific MCP servers                 |
| `criticalSystemReminder_EXPERIMENTAL` |     ✅      |   ❌    |  ✅   | Critical reminder (experimental)           |
| `skills`                              |     ✅      |   ❌    |  ✅   | Skills to preload into agent context       |
| `maxTurns`                            |     ✅      |   ❌    |  ✅   | Max agentic turns before stopping          |

---

## 10. Sandbox Settings

Sandbox configuration for command execution isolation.

### SandboxSettings

| Field                       | TypeScript | Python | Ruby |
|-----------------------------|:----------:|:------:|:----:|
| `enabled`                   |     ✅      |   ✅    |  ✅   |
| `autoAllowBashIfSandboxed`  |     ✅      |   ✅    |  ✅   |
| `excludedCommands`          |     ✅      |   ✅    |  ✅   |
| `allowUnsandboxedCommands`  |     ✅      |   ✅    |  ✅   |
| `network`                   |     ✅      |   ✅    |  ✅   |
| `ignoreViolations`          |     ✅      |   ✅    |  ✅   |
| `enableWeakerNestedSandbox` |     ✅      |   ✅    |  ✅   |
| `ripgrep`                   |     ✅      |   ❌    |  ✅   |
| `filesystem`                |     ✅      |   ❌    |  ✅   |

### SandboxFilesystemConfig

| Field        | TypeScript | Python | Ruby |
|--------------|:----------:|:------:|:----:|
| `allowWrite` |     ✅      |   ❌    |  ✅   |
| `denyWrite`  |     ✅      |   ❌    |  ✅   |
| `denyRead`   |     ✅      |   ❌    |  ✅   |

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
| `MessageParseError`  |     ❌      |   ❌    |  ✅   | Message parsing failed         |
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

| Feature          |    TypeScript    | Python | Ruby | Notes                                      |
|------------------|:----------------:|:------:|:----:|--------------------------------------------|
| `listSessions()` | ✅ `listSessions` |   ❌    |  ✅   | List past sessions with metadata (v0.2.53) |

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
| `reconnectMcpServer()`   |     ✅      |   ❌    |  ✅   | Reconnect MCP server                         |
| `toggleMcpServer()`      |     ✅      |   ❌    |  ✅   | Enable/disable MCP                           |
| `stopTask()`             |     ✅      |   ❌    |  ✅   | Stop running task                            |
| `streamInput()`          |     ✅      |   ✅    |  ✅   | Stream user input                            |
| `initializationResult()` |     ✅      |   ✅    |  ✅   | Full init response (Py: `get_server_info()`) |
| `close()`                |     ✅      |   ✅    |  ✅   | Close query/session                          |

### Client Class

| Feature              | TypeScript |       Python        |          Ruby           | Notes                                                                               |
|----------------------|:----------:|:-------------------:|:-----------------------:|-------------------------------------------------------------------------------------|
| Multi-turn client    |     ❌      | ✅ `ClaudeSDKClient` | ✅ `ClaudeAgent::Client` | Interactive sessions                                                                |
| `connect()`          |    N/A     |          ✅          |            ✅            | Start session                                                                       |
| `disconnect()`       |    N/A     |          ✅          |            ✅            | End session                                                                         |
| `send_message()`     |    N/A     |          ✅          |            ✅            | Send user message                                                                   |
| `receive_response()` |    N/A     |          ✅          |            ✅            | Receive until result                                                                |
| `stream_input()`     |    N/A     |          ❌          |            ✅            | Stream input messages                                                               |
| `abort!()`           |    N/A     |          ❌          |            ✅            | Abort operations                                                                    |
| Control methods      |    N/A     |       Partial       |            ✅            | interrupt, setPermissionMode, setModel, rewindFiles, mcpStatus (Python); all (Ruby) |

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
- v0.2.45: Added `TaskStartedMessage`, `RateLimitEvent` message types
- v0.2.47: Added `promptSuggestions` option and `PromptSuggestionMessage`
- v0.2.49: Added `ConfigChange` hook event, `SandboxFilesystemConfig`, ModelInfo capability fields
- v0.2.50: Added `WorktreeCreate`/`WorktreeRemove` hook events, `apply_flag_settings` control request
- v0.2.51: Added `TaskProgressMessage` for real-time background agent progress reporting
- v0.2.52: Added `mcp_authenticate`/`mcp_clear_auth` control requests for MCP server authentication
- v0.2.53: Added `listSessions()` for discovering and listing past sessions with `SDKSessionInfo` metadata
- v0.2.54 – v0.2.56: CLI parity updates (no new SDK-facing features)

### Python SDK
- Full source available with `Transport` abstract class
- Partial control protocol: query and client support interrupt, setPermissionMode, setModel, rewindFiles, mcpStatus
- Has `CLINotFoundError`, `CLIConnectionError`, `ProcessError`, `CLIJSONDecodeError` error types
- Missing hooks: SessionStart, SessionEnd, Setup, TeammateIdle, TaskCompleted, ConfigChange, WorktreeCreate, WorktreeRemove
- Missing permission modes: `dontAsk`
- Missing options: `allowDangerouslySkipPermissions`, `persistSession`, `resumeSessionAt`, `sessionId`, `strictMcpConfig`, `init`/`initOnly`/`maintenance`, `debug`/`debugFile`, `promptSuggestions`
- `ToolPermissionContext` missing `blockedPath`, `decisionReason`, `toolUseID`, `agentID`, `description`
- Has SDK MCP server support with `tool()` helper and annotations
- Added `thinking` config and `effort` option in v0.1.36
- Handles `rate_limit_event` and unknown message types gracefully (v0.1.40)
- Client has `get_server_info()` for accessing the initialization result (v0.1.31+)
- v0.1.42 – v0.1.43: CLI parity updates (no new SDK-facing features)

### Ruby SDK (This Repository)
- Feature parity with TypeScript SDK v0.2.56
- Ruby-idiomatic patterns (Data.define, snake_case)
- Complete control protocol, hook, and V2 Session API support
- Dedicated Client class for multi-turn conversations
- `executable`/`executableArgs` marked N/A (JS runtime options)
