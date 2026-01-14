# Claude Agent SDK Specification

This document provides a comprehensive specification of the Claude Agent SDK, comparing feature parity across the official TypeScript and Python SDKs with this Ruby implementation.

**Reference Versions:**
- TypeScript SDK: v0.2.7 (npm package)
- Python SDK: Latest from GitHub (commit 8602ff4)
- Ruby SDK: This repository

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

| Option                            | TypeScript | Python | Ruby | Notes                                                       |
|-----------------------------------|:----------:|:------:|:----:|-------------------------------------------------------------|
| `model`                           |     ✅      |   ✅    |  ✅   | Claude model identifier                                     |
| `fallbackModel`                   |     ✅      |   ✅    |  ✅   | Fallback if primary fails                                   |
| `systemPrompt`                    |     ✅      |   ✅    |  ✅   | String or preset object                                     |
| `appendSystemPrompt`              |     ✅      |   ❌    |  ✅   | Append to system prompt (TS SDK has via preset)             |
| `tools`                           |     ✅      |   ✅    |  ✅   | Array or preset                                             |
| `allowedTools`                    |     ✅      |   ✅    |  ✅   | Auto-allowed tools                                          |
| `disallowedTools`                 |     ✅      |   ✅    |  ✅   | Blocked tools                                               |
| `permissionMode`                  |     ✅      |   ✅    |  ✅   | default/acceptEdits/plan/bypassPermissions/delegate/dontAsk |
| `allowDangerouslySkipPermissions` |     ✅      |   ❌    |  ✅   | Required for bypassPermissions                              |
| `canUseTool`                      |     ✅      |   ✅    |  ✅   | Permission callback                                         |
| `permissionPromptToolName`        |     ✅      |   ✅    |  ✅   | MCP tool for permission prompts                             |
| `maxTurns`                        |     ✅      |   ✅    |  ✅   | Max conversation turns                                      |
| `maxBudgetUsd`                    |     ✅      |   ✅    |  ✅   | Max USD budget                                              |
| `maxThinkingTokens`               |     ✅      |   ✅    |  ✅   | Max thinking tokens                                         |
| `continue`                        |     ✅      |   ✅    |  ✅   | Continue most recent conversation                           |
| `resume`                          |     ✅      |   ✅    |  ✅   | Resume session by ID                                        |
| `resumeSessionAt`                 |     ✅      |   ❌    |  ✅   | Resume to specific message UUID                             |
| `forkSession`                     |     ✅      |   ✅    |  ✅   | Fork on resume                                              |
| `persistSession`                  |     ✅      |   ❌    |  ✅   | Whether to persist to disk                                  |
| `enableFileCheckpointing`         |     ✅      |   ✅    |  ✅   | Track file changes for rewind                               |
| `includePartialMessages`          |     ✅      |   ✅    |  ✅   | Include stream events                                       |
| `outputFormat`                    |     ✅      |   ✅    |  ✅   | JSON schema for structured output                           |
| `mcpServers`                      |     ✅      |   ✅    |  ✅   | MCP server configurations                                   |
| `strictMcpConfig`                 |     ✅      |   ❌    |  ✅   | Strict validation of MCP config                             |
| `hooks`                           |     ✅      |   ✅    |  ✅   | Hook callbacks                                              |
| `agents`                          |     ✅      |   ✅    |  ✅   | Custom subagent definitions                                 |
| `cwd`                             |     ✅      |   ✅    |  ✅   | Working directory                                           |
| `additionalDirectories`           |     ✅      |   ✅    |  ✅   | Extra allowed directories                                   |
| `env`                             |     ✅      |   ✅    |  ✅   | Environment variables                                       |
| `sandbox`                         |     ✅      |   ✅    |  ✅   | Sandbox settings                                            |
| `settingSources`                  |     ✅      |   ✅    |  ✅   | Which settings to load                                      |
| `plugins`                         |     ✅      |   ✅    |  ✅   | Plugin configurations                                       |
| `betas`                           |     ✅      |   ✅    |  ✅   | Beta features (e.g., context-1m-2025-08-07)                 |
| `abortController`                 |     ✅      |   ❌    |  ✅   | Cancellation controller                                     |
| `stderr`                          |     ✅      |   ✅    |  ✅   | Stderr callback                                             |
| `spawnClaudeCodeProcess`          |     ✅      |   ❌    |  ✅   | Custom spawn function                                       |
| `pathToClaudeCodeExecutable`      |     ✅      |   ✅    |  ✅   | Custom CLI path                                             |
| `executable`                      |     ✅      |  N/A   | N/A  | JS runtime (node/bun/deno) - JS-specific                    |
| `executableArgs`                  |     ✅      |  N/A   | N/A  | JS runtime args - JS-specific                               |
| `extraArgs`                       |     ✅      |   ✅    |  ✅   | Extra CLI arguments                                         |
| `user`                            |     ❌      |   ✅    |  ✅   | User identifier                                             |

---

## 2. Message Types

Messages exchanged between SDK and CLI.

| Message Type             | TypeScript | Python | Ruby | Notes                           |
|--------------------------|:----------:|:------:|:----:|---------------------------------|
| `UserMessage`            |     ✅      |   ✅    |  ✅   | User input                      |
| `UserMessageReplay`      |     ✅      |   ❌    |  ✅   | Replayed user message on resume |
| `AssistantMessage`       |     ✅      |   ✅    |  ✅   | Claude response                 |
| `SystemMessage`          |     ✅      |   ✅    |  ✅   | System/init messages            |
| `ResultMessage`          |     ✅      |   ✅    |  ✅   | Final result with usage         |
| `StreamEvent`            |     ✅      |   ✅    |  ✅   | Partial streaming events        |
| `CompactBoundaryMessage` |     ✅      |   ❌    |  ✅   | Conversation compaction marker  |
| `StatusMessage`          |     ✅      |   ❌    |  ✅   | Status updates (compacting)     |
| `ToolProgressMessage`    |     ✅      |   ❌    |  ✅   | Long-running tool progress      |
| `HookResponseMessage`    |     ✅      |   ❌    |  ✅   | Hook execution output           |
| `AuthStatusMessage`      |     ✅      |   ❌    |  ✅   | Authentication status           |

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

#### Result Subtypes

| Subtype                               | TypeScript | Python | Ruby | Notes                              |
|---------------------------------------|:----------:|:------:|:----:|------------------------------------|
| `success`                             |     ✅      |   ✅    |  ✅   | Successful completion              |
| `error_during_execution`              |     ✅      |   ✅    |  ✅   | Runtime error                      |
| `error_max_turns`                     |     ✅      |   ✅    |  ✅   | Max turns exceeded                 |
| `error_max_budget_usd`                |     ✅      |   ✅    |  ✅   | Budget exceeded                    |
| `error_max_structured_output_retries` |     ✅      |   ❌    |  ✅   | Structured output retries exceeded |

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
| `set_model`               |     ✅      |   ❌    |  ✅   | Change model                      |
| `set_max_thinking_tokens` |     ✅      |   ❌    |  ✅   | Change thinking tokens limit      |
| `rewind_files`            |     ✅      |   ✅    |  ✅   | Rewind file checkpoints           |
| `mcp_message`             |     ✅      |   ✅    |  ✅   | Route MCP message                 |
| `mcp_set_servers`         |     ✅      |   ❌    |  ✅   | Dynamically set MCP servers       |
| `mcp_status`              |     ✅      |   ❌    |  ✅   | Get MCP server status             |
| `supported_commands`      |     ✅      |   ❌    |  ✅   | Get available slash commands      |
| `supported_models`        |     ✅      |   ❌    |  ✅   | Get available models              |
| `account_info`            |     ✅      |   ❌    |  ✅   | Get account information           |

### Return Types

| Type                  | TypeScript | Python | Ruby | Notes                  |
|-----------------------|:----------:|:------:|:----:|------------------------|
| `SlashCommand`        |     ✅      |   ❌    |  ✅   | Available command info |
| `ModelInfo`           |     ✅      |   ❌    |  ✅   | Model information      |
| `McpServerStatus`     |     ✅      |   ❌    |  ✅   | MCP server status      |
| `AccountInfo`         |     ✅      |   ❌    |  ✅   | Account information    |
| `McpSetServersResult` |     ✅      |   ❌    |  ✅   | Set servers result     |
| `RewindFilesResult`   |     ✅      |   ✅    |  ✅   | Rewind result          |

---

## 5. Hooks

Event hooks for intercepting and modifying SDK behavior.

### Hook Events

| Event                | TypeScript | Python | Ruby | Notes                  |
|----------------------|:----------:|:------:|:----:|------------------------|
| `PreToolUse`         |     ✅      |   ✅    |  ✅   | Before tool execution  |
| `PostToolUse`        |     ✅      |   ✅    |  ✅   | After tool execution   |
| `PostToolUseFailure` |     ✅      |   ❌    |  ✅   | After tool failure     |
| `Notification`       |     ✅      |   ❌    |  ✅   | System notifications   |
| `UserPromptSubmit`   |     ✅      |   ✅    |  ✅   | User message submitted |
| `SessionStart`       |     ✅      |   ❌    |  ✅   | Session starts         |
| `SessionEnd`         |     ✅      |   ❌    |  ✅   | Session ends           |
| `Stop`               |     ✅      |   ✅    |  ✅   | Agent stops            |
| `SubagentStart`      |     ✅      |   ❌    |  ✅   | Subagent starts        |
| `SubagentStop`       |     ✅      |   ✅    |  ✅   | Subagent stops         |
| `PreCompact`         |     ✅      |   ✅    |  ✅   | Before compaction      |
| `PermissionRequest`  |     ✅      |   ❌    |  ✅   | Permission requested   |

### Hook Input Types

| Input Type                    | TypeScript | Python | Ruby |
|-------------------------------|:----------:|:------:|:----:|
| `PreToolUseHookInput`         |     ✅      |   ✅    |  ✅   |
| `PostToolUseHookInput`        |     ✅      |   ✅    |  ✅   |
| `PostToolUseFailureHookInput` |     ✅      |   ❌    |  ✅   |
| `NotificationHookInput`       |     ✅      |   ❌    |  ✅   |
| `UserPromptSubmitHookInput`   |     ✅      |   ✅    |  ✅   |
| `SessionStartHookInput`       |     ✅      |   ❌    |  ✅   |
| `SessionEndHookInput`         |     ✅      |   ❌    |  ✅   |
| `StopHookInput`               |     ✅      |   ✅    |  ✅   |
| `SubagentStartHookInput`      |     ✅      |   ❌    |  ✅   |
| `SubagentStopHookInput`       |     ✅      |   ✅    |  ✅   |
| `PreCompactHookInput`         |     ✅      |   ✅    |  ✅   |
| `PermissionRequestHookInput`  |     ✅      |   ❌    |  ✅   |

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
| `delegate`          |     ✅      |   ❌    |  ✅   | Delegate mode      |
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

| Field            | TypeScript | Python | Ruby | Notes                     |
|------------------|:----------:|:------:|:----:|---------------------------|
| `signal`         |     ✅      |   ✅    |  ✅   | Abort signal              |
| `suggestions`    |     ✅      |   ✅    |  ✅   | Permission suggestions    |
| `blockedPath`    |     ✅      |   ✅    |  ✅   | Blocked file path         |
| `decisionReason` |     ✅      |   ❌    |  ✅   | Why permission triggered  |
| `toolUseID`      |     ✅      |   ❌    |  ✅   | Tool call ID              |
| `agentID`        |     ✅      |   ❌    |  ✅   | Subagent ID if applicable |

---

## 7. MCP Support

Model Context Protocol server support.

### MCP Server Types

| Type    | TypeScript | Python | Ruby | Notes                 |
|---------|:----------:|:------:|:----:|-----------------------|
| `stdio` |     ✅      |   ✅    |  ✅   | Subprocess with stdio |
| `sse`   |     ✅      |   ✅    |  ✅   | Server-sent events    |
| `http`  |     ✅      |   ✅    |  ✅   | HTTP transport        |
| `sdk`   |     ✅      |   ✅    |  ✅   | In-process SDK server |

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

| Feature              | TypeScript | Python |         Ruby         | Notes                  |
|----------------------|:----------:|:------:|:--------------------:|------------------------|
| `createSdkMcpServer` |     ✅      |   ❌    |          ✅           | Create SDK server      |
| `tool()` helper      |     ✅      |   ❌    |          ✅           | Create tool definition |
| Tool input schema    |  ✅ (Zod)   |   ❌    | ✅ (Hash/JSON Schema) | Schema definition      |

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

### SandboxNetworkConfig

| Field                 | TypeScript | Python | Ruby |
|-----------------------|:----------:|:------:|:----:|
| `allowedDomains`      |     ✅      |   ❌    |  ✅   |
| `allowUnixSockets`    |     ✅      |   ✅    |  ✅   |
| `allowAllUnixSockets` |     ✅      |   ✅    |  ✅   |
| `allowLocalBinding`   |     ✅      |   ✅    |  ✅   |
| `httpProxyPort`       |     ✅      |   ✅    |  ✅   |
| `socksProxyPort`      |     ✅      |   ✅    |  ✅   |

---

## 11. Error Handling

Error types and hierarchy.

| Error Type           | TypeScript | Python | Ruby | Notes                          |
|----------------------|:----------:|:------:|:----:|--------------------------------|
| Base Error           |     ✅      |   ✅    |  ✅   | `Error` / `ClaudeAgent::Error` |
| `AbortError`         |     ✅      |   ❌    |  ✅   | Operation cancelled            |
| `CLINotFoundError`   |     ❌      |   ❌    |  ✅   | CLI not found                  |
| `CLIVersionError`    |     ❌      |   ❌    |  ✅   | CLI version too old            |
| `CLIConnectionError` |     ❌      |   ❌    |  ✅   | Connection failed              |
| `ProcessError`       |     ❌      |   ❌    |  ✅   | CLI process failed             |
| `JSONDecodeError`    |     ❌      |   ❌    |  ✅   | JSON parsing failed            |
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

---

## 12. Client API

Public API surface for SDK clients.

### Query Interface

| Feature                 | TypeScript  |   Python    |          Ruby           | Notes              |
|-------------------------|:-----------:|:-----------:|:-----------------------:|--------------------|
| One-shot query function | ✅ `query()` | ✅ `query()` | ✅ `ClaudeAgent.query()` | Simple prompts     |
| Returns async generator |      ✅      |      ✅      |     ✅ (Enumerator)      | Streaming messages |

### Query Control Methods (TypeScript)

| Method                   | TypeScript | Python | Ruby | Notes                  |
|--------------------------|:----------:|:------:|:----:|------------------------|
| `interrupt()`            |     ✅      |   ❌    |  ✅   | Interrupt execution    |
| `setPermissionMode()`    |     ✅      |   ❌    |  ✅   | Change permission mode |
| `setModel()`             |     ✅      |   ❌    |  ✅   | Change model           |
| `setMaxThinkingTokens()` |     ✅      |   ❌    |  ✅   | Set thinking limit     |
| `supportedCommands()`    |     ✅      |   ❌    |  ✅   | Get slash commands     |
| `supportedModels()`      |     ✅      |   ❌    |  ✅   | Get available models   |
| `mcpServerStatus()`      |     ✅      |   ❌    |  ✅   | Get MCP status         |
| `accountInfo()`          |     ✅      |   ❌    |  ✅   | Get account info       |
| `rewindFiles()`          |     ✅      |   ✅    |  ✅   | Rewind file changes    |
| `setMcpServers()`        |     ✅      |   ❌    |  ✅   | Dynamic MCP servers    |
| `streamInput()`          |     ✅      |   ❌    |  ✅   | Stream user input      |

### Client Class

| Feature              | TypeScript |       Python        |          Ruby           | Notes                          |
|----------------------|:----------:|:-------------------:|:-----------------------:|--------------------------------|
| Multi-turn client    |     ❌      | ✅ `ClaudeSDKClient` | ✅ `ClaudeAgent::Client` | Interactive sessions           |
| `connect()`          |    N/A     |          ✅          |            ✅            | Start session                  |
| `disconnect()`       |    N/A     |          ✅          |            ✅            | End session                    |
| `send_message()`     |    N/A     |          ✅          |            ✅            | Send user message              |
| `receive_response()` |    N/A     |          ✅          |            ✅            | Receive until result           |
| `stream_input()`     |    N/A     |          ❌          |            ✅            | Stream input messages          |
| `abort!()`           |    N/A     |          ❌          |            ✅            | Abort operations               |
| Control methods      |    N/A     |       Partial       |            ✅            | All TypeScript control methods |

### Transport

| Feature               | TypeScript | Python | Ruby | Notes                    |
|-----------------------|:----------:|:------:|:----:|--------------------------|
| `Transport` interface |     ✅      |   ❌    |  ✅   | Transport abstraction    |
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
- Version 0.2.7 includes `maxOutputTokens` field in `ModelUsage`
- Adds `deno` as supported executable option
- Includes experimental `criticalSystemReminder_EXPERIMENTAL` for agent definitions

### Python SDK
- Full source available
- Fewer control protocol features than TypeScript
- Does not support SessionStart/SessionEnd/Notification hooks due to setup limitations
- Missing several permission modes (delegate, dontAsk)
- `excludedCommands` in sandbox now supported
- `tool_use_id` now included in PreToolUseHookInput

### Ruby SDK (This Repository)
- Full TypeScript SDK feature parity achieved
- Ruby-idiomatic patterns (Data.define, snake_case)
- Complete control protocol support
- Dedicated Client class for multi-turn conversations
- Full hook event support including all 12 events
- Full V2 Session API support (unstable)
- `executable`/`executableArgs` marked N/A (JS runtime options not applicable to Ruby)
