# TypeScript SDK Architecture: Data Flow

How data flows through the `@anthropic-ai/claude-agent-sdk`. Not about specific classes — about **concepts**, what they wrap, and where data lives.

## The Big Picture

The SDK is a **process bridge**. It spawns the Claude Code CLI as a subprocess and communicates over JSON Lines via stdin/stdout. Everything flows through this pipe.

```mermaid
graph TB
    subgraph "SDK Process (your app)"
        USER["Your Code"]
        Q["query() / SDKSession"]
        OPT["Options"]
        CP["Control Protocol"]
        HOOKS["Hook Callbacks"]
        MCP_SDK["SDK MCP Servers"]
        PERM["canUseTool Callback"]
    end

    subgraph "CLI Subprocess"
        CLI["Claude Code CLI"]
        CLAUDE_API["Claude API"]
        MCP_EXT["External MCP Servers"]
        TOOLS["Built-in Tools\n(Bash, Read, Edit...)"]
    end

    USER -->|"prompt + options"| Q
    Q -->|"builds CLI args + env"| OPT
    OPT -->|"spawns process"| CLI
    Q <-->|"JSON Lines\nstdin/stdout"| CP
    CP <-->|"control_request/\ncontrol_response"| CLI
    CLI <-->|"API calls"| CLAUDE_API
    CLI <-->|"stdio/SSE/HTTP"| MCP_EXT
    CLI -->|"executes"| TOOLS
    CP -->|"routes"| HOOKS
    CP -->|"routes"| MCP_SDK
    CP -->|"routes"| PERM
```

## Two Message Channels on One Pipe

All messages flow through one stdin/stdout pipe, but the Control Protocol splits them into two logical channels:

```mermaid
graph LR
    subgraph "stdout from CLI"
        RAW["Raw JSON Lines"]
    end

    RAW -->|"type: control_request\ntype: control_response"| CTRL["Control Channel\n(handled in-process)"]
    RAW -->|"type: assistant\ntype: result\ntype: system\ntype: user\n..."| SDK_Q["SDK Channel\n(queued for your code)"]

    CTRL -->|"can_use_tool"| PERM["Permission Callback"]
    CTRL -->|"hook_callback"| HOOK["Hook Callbacks"]
    CTRL -->|"mcp_message"| MCP["SDK MCP Server"]
    CTRL -->|"elicitation"| ELICIT["Elicitation Callback"]

    SDK_Q --> PARSE["Message Parser"]
    PARSE --> TYPED["Typed SDK Messages\n(SDKMessage union)"]
```

## Data Flow: A Complete Turn

```mermaid
sequenceDiagram
    participant App as Your Code
    participant Q as query()
    participant CP as Control Protocol
    participant T as Transport (stdin/stdout)
    participant CLI as Claude Code CLI
    participant API as Claude API

    Note over Q,T: 1. SETUP
    App->>Q: query({ prompt, options })
    Q->>T: spawn("claude", [...args])
    T->>CLI: process starts
    Q->>CP: start(streaming: true)
    CP->>T: write: {type: "control_request",\nrequest: {subtype: "initialize",\nhooks, sdkMcpServers, agents...}}
    CLI-->>T: {type: "control_response",\nresponse: {commands, models, account...}}
    CP-->>Q: initialized

    Note over Q,T: 2. SEND PROMPT
    CP->>T: write: {type: "user",\nmessage: {role: "user", content: "..."}}

    Note over CLI,API: 3. CLI PROCESSES
    CLI->>API: messages.create(...)
    API-->>CLI: streaming response

    Note over Q,T: 4. PERMISSION CHECK (if tool use)
    CLI-->>T: {type: "control_request",\nrequest: {subtype: "can_use_tool",\ntool_name: "Bash"...}}
    CP->>App: canUseTool("Bash", input, options)
    App-->>CP: {behavior: "allow"}
    CP->>T: write: {type: "control_response",\nresponse: {behavior: "allow"}}

    Note over Q,T: 5. STREAM RESULTS
    CLI-->>T: {type: "assistant",\nmessage: {content: [...]}}
    T-->>CP: routes to SDK queue
    CP-->>Q: SDKAssistantMessage
    Q-->>App: yield message

    CLI-->>T: {type: "result",\nsubtype: "success", result: "...", usage: {...}}
    T-->>CP: routes to SDK queue
    CP-->>Q: SDKResultMessage
    Q-->>App: yield message (iteration ends)
```

## What Wraps CLI Data vs. What's an SDK Abstraction

### SDK Abstractions

Invented by the SDK — not in the CLI's JSON protocol.

| Concept                | What it does                                                                                                            |
|------------------------|-------------------------------------------------------------------------------------------------------------------------|
| `query()`              | Entry point. Returns `AsyncGenerator<SDKMessage>`. Spawns process, runs handshake, sends prompt, yields typed messages. |
| `SDKSession`           | V2 multi-turn session interface. `.send()` / `.stream()` / `.close()`.                                                  |
| `Options`              | Converts user config into CLI args + env vars. The SDK's configuration surface.                                         |
| Control Protocol       | Routes messages between two channels. Manages request/response matching with IDs.                                       |
| `canUseTool`           | Permission callback. CLI sends a control request, SDK routes it to your function.                                       |
| `HookCallback`         | In-process hook execution. CLI sends hook input, SDK calls your function, returns result.                               |
| `createSdkMcpServer()` | Hosts an MCP server in your process. CLI routes MCP messages to it via control protocol.                                |
| `onElicitation`        | User input callback for MCP OAuth flows.                                                                                |
| Query methods          | `.interrupt()`, `.setModel()`, `.rewindFiles()`, `.setMcpServers()` — all send control requests.                        |
| `listSessions()`       | Reads the CLI's session JSONL files from disk. No subprocess involved.                                                  |
| `getSessionMessages()` | Parses the CLI's transcript format from disk.                                                                           |

### CLI Protocol Wrappers

Direct 1:1 mapping of JSON the CLI sends/receives. The SDK adds TypeScript types but doesn't transform the data.

| Type                                   | CLI JSON it wraps                                                                                            |
|----------------------------------------|--------------------------------------------------------------------------------------------------------------|
| `SDKAssistantMessage`                  | `{type: "assistant", message: BetaMessage}`                                                                  |
| `SDKUserMessage`                       | `{type: "user", message: MessageParam}`                                                                      |
| `SDKResultMessage`                     | `{type: "result", subtype: "success"\|"error_*"}`                                                            |
| `SDKSystemMessage`                     | `{type: "system", subtype: "init"}`                                                                          |
| `SDKStatusMessage`                     | `{type: "system", subtype: "status"}`                                                                        |
| `SDKPartialAssistantMessage`           | `{type: "stream_event", event: ...}`                                                                         |
| `SDKHookStarted/Progress/Response`     | Hook lifecycle messages                                                                                      |
| `SDKTaskStarted/Progress/Notification` | Subagent task messages                                                                                       |
| `SDKToolProgressMessage`               | Tool execution progress                                                                                      |
| `SDKRateLimitEvent`                    | Rate limit state changes                                                                                     |
| `SDKCompactBoundaryMessage`            | Context compaction markers                                                                                   |
| `SDKFilesPersistedEvent`               | File checkpoint events                                                                                       |
| `SDKElicitationCompleteMessage`        | MCP elicitation completion                                                                                   |
| `SDKPromptSuggestionMessage`           | Predicted next prompt                                                                                        |
| Control request/response types         | `initialize`, `can_use_tool`, `hook_callback`, `mcp_message`, `interrupt`, `set_model`, `rewind_files`, etc. |

### Configuration Wrappers

SDK types that map to CLI flags, env vars, or config JSON.

| SDK Type               | Maps to                                      |
|------------------------|----------------------------------------------|
| `PermissionMode`       | `--permission-mode` flag                     |
| `McpStdioServerConfig` | MCP server config JSON                       |
| `AgentDefinition`      | `--agents` JSON config                       |
| `SandboxSettings`      | `--sandbox-settings` JSON                    |
| `OutputFormat`         | `--output-format` config                     |
| `ThinkingConfig`       | `--thinking` / `--max-thinking-tokens`       |
| `SystemPrompt`         | `--system-prompt` / `--append-system-prompt` |
| `SettingSource`        | `--settings-sources` flag                    |

### Pass-through Types

Types from upstream protocols that flow through untouched. The SDK re-exports them for convenience.

| Type                        | Source                                        |
|-----------------------------|-----------------------------------------------|
| `BetaMessage`               | `@anthropic-ai/sdk` (Anthropic API response)  |
| `BetaUsage`                 | `@anthropic-ai/sdk` (token counts from API)   |
| `MessageParam`              | `@anthropic-ai/sdk` (API input format)        |
| `BetaRawMessageStreamEvent` | `@anthropic-ai/sdk` (streaming chunks)        |
| `JSONRPCMessage`            | `@modelcontextprotocol/sdk` (MCP wire format) |
| `CallToolResult`            | `@modelcontextprotocol/sdk` (MCP tool output) |
| `ElicitResult`              | `@modelcontextprotocol/sdk` (MCP user input)  |

## The Three Layers

```mermaid
graph TB
    subgraph L3["Layer 3: SDK Abstractions"]
        direction LR
        query["query()"]
        session["SDKSession"]
        opts["Options builder"]
        ctrl["Control Protocol"]
        callbacks["Callbacks\n(canUseTool, hooks,\nonElicitation)"]
        session_mgmt["Session Management\n(listSessions,\ngetSessionMessages)"]
    end

    subgraph L2["Layer 2: CLI Protocol Types"]
        direction LR
        msgs["SDKMessage union\n(21+ message types)"]
        ctrl_req["Control Requests\n(initialize, can_use_tool,\nhook_callback, ...)"]
        ctrl_resp["Control Responses"]
    end

    subgraph L1["Layer 1: Pass-through Types"]
        direction LR
        beta["BetaMessage\n(Anthropic API)"]
        usage["BetaUsage\n(Anthropic API)"]
        msgparam["MessageParam\n(Anthropic API)"]
        jsonrpc["JSONRPCMessage\n(MCP protocol)"]
        content["Content Blocks\n(text, tool_use, thinking)"]
    end

    L3 --> L2
    L2 --> L1

    style L3 fill:#e1f5fe
    style L2 fill:#fff3e0
    style L1 fill:#f3e5f5
```

**Layer 1 (Pass-through):** Types from the Anthropic API and MCP protocol. The CLI's `SDKAssistantMessage.message` is literally a `BetaMessage` from the API. The SDK doesn't interpret content blocks — they're whatever the API returned.

**Layer 2 (CLI Protocol):** The JSON shapes the CLI sends/receives over JSON Lines. The SDK defines TypeScript types for them but doesn't transform the data. It's a typed window into what the CLI emits.

**Layer 3 (SDK Abstractions):** Things the SDK invents. `query()` is not a CLI concept — it's an ergonomic wrapper that spawns a process, runs the control protocol handshake, sends the prompt, and yields typed messages. The Control Protocol's routing logic is an SDK concept. The CLI just sends a control request and blocks until it gets a response.

## Key Insight: The SDK is Thin Where It Matters

The SDK deliberately avoids re-interpreting CLI data. It doesn't parse content blocks into rich objects, doesn't build conversation trees, doesn't accumulate state. It's a **typed streaming bridge**:

```
Your prompt --> Options --> CLI args --> subprocess --> JSON Lines --> typed messages --> your code
                                            ^                              |
                                            +-- control requests <---------+
                                                (permissions, hooks, MCP)
```

The "intelligence" lives in three places:
1. **The CLI** — runs Claude, manages tools, handles the API
2. **The Control Protocol** — routes bidirectional requests between CLI and your callbacks
3. **Your code** — decides permissions, handles hooks, processes messages
