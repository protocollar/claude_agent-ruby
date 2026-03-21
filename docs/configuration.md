# Configuration

The ClaudeAgent Ruby SDK uses a layered configuration system inspired by the Stripe Ruby gem. Global defaults are set once at boot and apply to every request. Per-request overrides refine or replace those defaults for a single `ask`, `chat`, or `Conversation`.

## Table of Contents

- [Global Configuration](#global-configuration)
- [Configuration Tiers](#configuration-tiers)
- [Per-Request Overrides](#per-request-overrides)
- [Options Class Reference](#options-class-reference)
- [Tools Preset](#tools-preset)
- [Sandbox Settings](#sandbox-settings)
- [Custom Agents](#custom-agents)
- [Environment Variables](#environment-variables)

---

## Global Configuration

### Module-level setters

Set individual defaults directly on the `ClaudeAgent` module:

```ruby
ClaudeAgent.model = "opus"
ClaudeAgent.permission_mode = "acceptEdits"
ClaudeAgent.max_turns = 10
ClaudeAgent.debug = true
```

### Block-based bulk configuration

Use `configure` to set multiple defaults in one call:

```ruby
ClaudeAgent.configure do |c|
  c.model = "opus"
  c.permission_mode = "acceptEdits"
  c.max_turns = 10
  c.max_budget_usd = 1.00
  c.system_prompt = "You are a code review assistant."
  c.cwd = "/path/to/project"
end
```

### Resetting to defaults

```ruby
ClaudeAgent.reset_config!
```

This replaces the current `Configuration` with a fresh instance where all fields are `nil` (or their constructor defaults).

### Global permissions

Register a declarative permission policy that applies to all requests:

```ruby
ClaudeAgent.permissions do |p|
  p.allow "Read", "Grep", "Glob"
  p.deny "Bash", message: "Bash not allowed"
  p.deny_all
end
```

### Global hooks

Register hooks that fire for all requests:

```ruby
ClaudeAgent.hooks do |h|
  h.before_tool_use(/Bash/) { |input, ctx| { continue_: true } }
  h.on_session_start { |input, ctx| { continue_: true } }
end
```

### Global MCP servers

Register MCP servers that are included in all requests:

```ruby
server = ClaudeAgent::MCP::Server.new(name: "calculator") do |s|
  s.tool("add", "Add numbers", { a: :number, b: :number }) do |args|
    args[:a] + args[:b]
  end
end

ClaudeAgent.register_mcp_server(server)
```

---

## Configuration Tiers

The `Configuration` class organizes fields into three tiers based on how they are typically used.

### Tier 1 – Module-level delegators

These fields have convenience delegators on the `ClaudeAgent` module itself (`ClaudeAgent.model = "opus"`). They represent settings that are typically set once at boot time.

| Field                  | Type              | Description                                                              |
|------------------------|-------------------|--------------------------------------------------------------------------|
| `model`                | `String`          | Model name or alias (e.g., `"opus"`, `"sonnet"`)                         |
| `permission_mode`      | `String`          | One of: `default`, `acceptEdits`, `plan`, `bypassPermissions`, `dontAsk` |
| `max_turns`            | `Integer`         | Maximum agentic turns per request                                        |
| `max_budget_usd`       | `Float`           | Maximum cost in USD per request                                          |
| `system_prompt`        | `String`, `Hash`  | Custom system prompt (replaces default)                                  |
| `append_system_prompt` | `String`          | Appended to the default system prompt                                    |
| `cli_path`             | `String`          | Path to `claude` CLI binary                                              |
| `cwd`                  | `String`          | Working directory for CLI process                                        |
| `sandbox`              | `SandboxSettings` | Sandbox configuration (see below)                                        |
| `debug`                | `Boolean`         | Enable CLI `--debug` flag                                                |
| `effort`               | `String`          | Effort level: `low`, `medium`, `high`, `max`                             |
| `persist_session`      | `Boolean`         | Persist session to disk (default: `true`)                                |
| `fallback_model`       | `String`          | Fallback model when primary is unavailable                               |

### Tier 2 – Per-request overrides

These fields are commonly set as keyword arguments on `ask`, `chat`, or `Conversation.new`. They are also configurable via the global `Configuration`.

| Field              | Type                           | Description                                                                                                  |
|--------------------|--------------------------------|--------------------------------------------------------------------------------------------------------------|
| `tools`            | `Array`, `ToolsPreset`, `Hash` | Tools available to the model                                                                                 |
| `allowed_tools`    | `Array<String>`                | Allowlist of tool names                                                                                      |
| `disallowed_tools` | `Array<String>`                | Denylist of tool names                                                                                       |
| `thinking`         | `Hash`                         | Thinking config: `{ type: "adaptive" }`, `{ type: "enabled", budget_tokens: 10000 }`, `{ type: "disabled" }` |
| `output_format`    | `Hash`                         | JSON Schema for structured output                                                                            |

### Tier 3 – Advanced

These fields are accessible via `ClaudeAgent.configure` or by constructing `Options` directly. They cover MCP servers, hooks, environment, plugins, and internal SDK plumbing.

| Field                       | Type                   | Description                                               |
|-----------------------------|------------------------|-----------------------------------------------------------|
| `mcp_servers`               | `Hash`                 | MCP server configurations                                 |
| `hooks`                     | `Hash`, `HookRegistry` | Hook event handlers                                       |
| `env`                       | `Hash`                 | Extra environment variables for CLI process               |
| `extra_args`                | `Hash`                 | Additional CLI flags (`{ "--flag" => "value" }`)          |
| `agents`                    | `Hash`                 | Custom agent definitions (see below)                      |
| `setting_sources`           | `Array`                | Setting source overrides                                  |
| `settings`                  | `String`, `Hash`       | Inline settings or path to settings file                  |
| `plugins`                   | `Array`                | Plugin directories                                        |
| `betas`                     | `Array`                | Beta feature flags                                        |
| `spawn_claude_code_process` | `Proc`                 | Custom spawn function (Docker, SSH, etc.)                 |
| `agent`                     | `String`               | Built-in agent to use (e.g., `"Explore"`)                 |
| `add_dirs`                  | `Array`                | Additional directories to include                         |
| `max_buffer_size`           | `Integer`              | Max JSON buffer size (default: 1MB)                       |
| `stderr_callback`           | `Proc`                 | Callback for stderr output                                |
| `include_partial_messages`  | `Boolean`              | Include partial streaming messages                        |
| `enable_file_checkpointing` | `Boolean`              | Enable file checkpointing                                 |
| `prompt_suggestions`        | `Boolean`              | Enable prompt suggestions                                 |
| `strict_mcp_config`         | `Boolean`              | Strict MCP config validation                              |
| `tool_config`               | `Hash`                 | Per-tool configuration                                    |
| `agent_progress_summaries`  | any                    | Agent progress summary configuration                      |
| `max_thinking_tokens`       | `Integer`              | Max thinking tokens (standalone, without `thinking` hash) |
| `debug_file`                | `String`               | Path to debug log file                                    |

---

## Per-Request Overrides

When you call `ask`, `chat`, or create a `Conversation`, keyword arguments merge with the global configuration. Per-request values always win over config defaults.

### With `ask`

```ruby
# Uses global config defaults
turn = ClaudeAgent.ask("What is 2+2?")

# Per-request overrides: model and max_turns override config
turn = ClaudeAgent.ask("Fix the bug",
  model: "opus",
  max_turns: 5,
  system_prompt: "You are a debugging expert."
)

# Event callbacks are also passed as kwargs
turn = ClaudeAgent.ask("Explain Ruby",
  on_stream: ->(text) { print text },
  on_tool_use: ->(tool) { puts "Tool: #{tool.name}" }
)
```

### With `chat`

```ruby
# Global config applies to the conversation
ClaudeAgent.chat(model: "opus", max_turns: 10) do |c|
  c.say("Hello")
  c.say("Now add tests")
end

# Without block -- caller manages lifecycle
c = ClaudeAgent.chat(permission_mode: "acceptEdits")
c.say("Refactor this module")
c.close
```

### With `Conversation.new`

```ruby
conversation = ClaudeAgent::Conversation.new(
  model: "opus",
  max_turns: 10,
  on_stream: ->(text) { print text },
  on_permission: :accept_edits
)
```

### Merge behavior

The merge follows a simple rule: **per-request wins**.

```ruby
ClaudeAgent.model = "sonnet"
ClaudeAgent.max_turns = 20

# model = "opus" (overridden), max_turns = 20 (from config)
turn = ClaudeAgent.ask("Hello", model: "opus")
```

Internally, `Configuration#to_options` iterates all fields. If a per-request override is provided (even if `nil`), it takes precedence. If no override is provided, the config default is used. The result is a fully resolved `Options` instance.

### Pre-built Options

You can bypass the config merge entirely by passing a pre-built `Options` object:

```ruby
opts = ClaudeAgent::Options.new(
  model: "opus",
  max_turns: 5,
  permission_mode: "acceptEdits"
)

# Global config is ignored -- opts is used directly
turn = ClaudeAgent.ask("Fix the bug", options: opts)
```

---

## Options Class Reference

`ClaudeAgent::Options` is the fully-resolved configuration object passed to the transport layer. It validates all fields at construction time and serializes them to CLI arguments and environment variables.

### Constructor

```ruby
options = ClaudeAgent::Options.new(
  # --- Model ---
  model: "opus",
  fallback_model: "sonnet",

  # --- Tools ---
  tools: ["Read", "Write", "Bash"],          # Array of tool names
  # tools: ToolsPreset.new(preset: "claude_code"),  # Or a preset
  # tools: { type: "preset", preset: "claude_code" },  # Or Hash shorthand
  allowed_tools: [],                          # Allowlist (default: [])
  disallowed_tools: [],                       # Denylist (default: [])

  # --- System prompt ---
  system_prompt: "You are a helpful assistant.",
  append_system_prompt: "Always respond in JSON.",

  # --- Permissions ---
  permission_mode: "acceptEdits",             # "default", "acceptEdits", "plan", "bypassPermissions", "dontAsk"
  permission_prompt_tool_name: nil,           # Auto-set to "stdio" when can_use_tool is present
  can_use_tool: ->(name, input, ctx) { { behavior: "allow" } },
  on_elicitation: ->(data) { { behavior: "allow" } },
  allow_dangerously_skip_permissions: false,   # Required for bypassPermissions mode
  permission_queue: nil,                       # Enable permission queue (Conversation default)

  # --- Session ---
  continue_conversation: false,
  resume: nil,                                # Session ID to resume
  fork_session: false,
  resume_session_at: nil,
  session_id: nil,
  persist_session: true,                      # Default: true

  # --- Limits ---
  max_turns: nil,                             # Positive integer
  max_budget_usd: nil,                        # Positive number
  effort: nil,                                # "low", "medium", "high", "max"

  # --- Thinking ---
  thinking: nil,                              # { type: "adaptive" }, { type: "enabled", budget_tokens: 10000 }, { type: "disabled" }
  max_thinking_tokens: nil,                   # Standalone (without thinking hash)

  # --- MCP ---
  mcp_servers: {},                            # Default: {}
  strict_mcp_config: false,

  # --- Hooks ---
  hooks: nil,                                 # Hash or HookRegistry

  # --- Sandbox ---
  sandbox: nil,                               # SandboxSettings instance

  # --- Environment ---
  cwd: nil,
  add_dirs: [],                               # Default: []
  env: {},                                    # Default: {}
  agent: nil,                                 # Built-in agent name
  agents: nil,                                # Hash of AgentDefinition
  cli_path: nil,

  # --- Output ---
  output_format: nil,                         # JSON Schema for structured output
  include_partial_messages: false,
  enable_file_checkpointing: false,
  prompt_suggestions: false,

  # --- Advanced ---
  extra_args: {},                             # Default: {}
  setting_sources: nil,
  settings: nil,
  plugins: [],                                # Default: []
  betas: [],                                  # Default: []
  max_buffer_size: nil,                       # Default: 1MB
  stderr_callback: nil,
  abort_controller: nil,
  spawn_claude_code_process: nil,
  tool_config: nil,
  agent_progress_summaries: nil,
  logger: nil,                                # Per-instance logger override

  # --- Debug ---
  debug: false,
  debug_file: nil
)
```

### Defaults

Fields with non-nil defaults:

| Field                                | Default |
|--------------------------------------|---------|
| `allowed_tools`                      | `[]`    |
| `disallowed_tools`                   | `[]`    |
| `allow_dangerously_skip_permissions` | `false` |
| `continue_conversation`              | `false` |
| `fork_session`                       | `false` |
| `strict_mcp_config`                  | `false` |
| `mcp_servers`                        | `{}`    |
| `add_dirs`                           | `[]`    |
| `env`                                | `{}`    |
| `extra_args`                         | `{}`    |
| `plugins`                            | `[]`    |
| `include_partial_messages`           | `false` |
| `enable_file_checkpointing`          | `false` |
| `persist_session`                    | `true`  |
| `betas`                              | `[]`    |
| `prompt_suggestions`                 | `false` |
| `debug`                              | `false` |

### Validation

`Options` validates at construction and raises `ClaudeAgent::ConfigurationError` for:

- Invalid `permission_mode` (must be one of `default`, `acceptEdits`, `plan`, `bypassPermissions`, `dontAsk`)
- `bypassPermissions` without `allow_dangerously_skip_permissions: true`
- Non-callable `can_use_tool` (must respond to `#call`)
- Non-callable `on_elicitation` (must respond to `#call`)
- Non-positive `max_turns` or `max_budget_usd`
- Invalid `thinking` hash (`:type` must be `adaptive`, `enabled`, or `disabled`)
- Invalid `effort` (must be `low`, `medium`, `high`, or `max`)
- `session_id` with `continue_conversation` or `resume` unless `fork_session` is also set

### Serialization

`Options` includes a `Serializer` module that converts to CLI arguments and environment variables:

```ruby
options.to_cli_args  # => ["--model", "opus", "--max-turns", "10", ...]
options.to_env       # => {"CLAUDE_CODE_ENTRYPOINT" => "sdk-rb", ...}
```

---

## Tools Preset

Use `ToolsPreset` to select a named preset instead of listing individual tools:

```ruby
preset = ClaudeAgent::ToolsPreset.new(preset: "claude_code")
options = ClaudeAgent::Options.new(tools: preset)
```

The `type` field defaults to `"preset"`. You can also pass a plain Hash:

```ruby
options = ClaudeAgent::Options.new(
  tools: { type: "preset", preset: "claude_code" }
)
```

Or pass an Array of tool name strings:

```ruby
options = ClaudeAgent::Options.new(
  tools: ["Read", "Write", "Bash", "Grep", "Glob"]
)
```

---

## Sandbox Settings

`SandboxSettings` configures execution sandboxing for the CLI process. It is an immutable `ImmutableRecord` type.

### Basic sandbox

```ruby
sandbox = ClaudeAgent::SandboxSettings.new(enabled: true)

ClaudeAgent.sandbox = sandbox
# or
ClaudeAgent.configure { |c| c.sandbox = sandbox }
```

### Full configuration

```ruby
sandbox = ClaudeAgent::SandboxSettings.new(
  enabled: true,
  auto_allow_bash_if_sandboxed: true,
  excluded_commands: ["docker"],
  allow_unsandboxed_commands: false,
  enable_weaker_nested_sandbox: false,
  enable_weaker_network_isolation: false,
  network: ClaudeAgent::SandboxNetworkConfig.new(
    allowed_domains: ["api.example.com", "registry.npmjs.org"],
    allow_local_binding: true,
    allow_unix_sockets: ["/var/run/docker.sock"],
    allow_all_unix_sockets: false,
    allow_managed_domains_only: false,
    http_proxy_port: nil,
    socks_proxy_port: nil
  ),
  filesystem: ClaudeAgent::SandboxFilesystemConfig.new(
    allow_write: ["/tmp/*"],
    deny_write: ["/etc/*"],
    deny_read: ["/secrets/*"]
  ),
  ignore_violations: ClaudeAgent::SandboxIgnoreViolations.new(
    file: ["/tmp/*"],
    network: ["localhost:*"]
  ),
  ripgrep: ClaudeAgent::SandboxRipgrepConfig.new(
    command: "/usr/local/bin/rg",
    args: ["--hidden"]
  )
)
```

### Sub-configuration types

| Type                      | Fields                                                                                                                                                                                                                   |
|---------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `SandboxSettings`         | `enabled`, `auto_allow_bash_if_sandboxed`, `excluded_commands`, `allow_unsandboxed_commands`, `network`, `ignore_violations`, `enable_weaker_nested_sandbox`, `enable_weaker_network_isolation`, `ripgrep`, `filesystem` |
| `SandboxNetworkConfig`    | `allowed_domains`, `allow_local_binding`, `allow_unix_sockets`, `allow_all_unix_sockets`, `allow_managed_domains_only`, `http_proxy_port`, `socks_proxy_port`                                                            |
| `SandboxFilesystemConfig` | `allow_write`, `deny_write`, `deny_read`                                                                                                                                                                                 |
| `SandboxIgnoreViolations` | `file`, `network`                                                                                                                                                                                                        |
| `SandboxRipgrepConfig`    | `command`, `args`                                                                                                                                                                                                        |

All sandbox types implement `to_h` for serialization to the CLI's JSON format.

---

## Custom Agents

Define custom subagents using `AgentDefinition`:

```ruby
test_runner = ClaudeAgent::AgentDefinition.new(
  description: "Runs tests and reports results",
  prompt: "You are a test runner. Run the specified tests and report pass/fail status.",
  tools: ["Read", "Grep", "Glob", "Bash"],
  model: "haiku",
  max_turns: 10
)

research = ClaudeAgent::AgentDefinition.new(
  description: "Research agent with specialized skills",
  prompt: "You are a research expert. Find and summarize information.",
  skills: ["web-search", "summarization"],
  disallowed_tools: ["Write", "Edit"],
  mcp_servers: { "search" => { "command" => "npx", "args" => ["-y", "search-server"] } },
  critical_system_reminder: "Never modify files."
)

options = ClaudeAgent::Options.new(
  agents: {
    "test_runner" => test_runner,
    "research" => research
  }
)
```

### AgentDefinition fields

| Field                      | Type            | Required | Description                          |
|----------------------------|-----------------|----------|--------------------------------------|
| `description`              | `String`        | Yes      | What this agent does                 |
| `prompt`                   | `String`        | Yes      | System prompt for the agent          |
| `tools`                    | `Array<String>` | No       | Tools available to this agent        |
| `disallowed_tools`         | `Array<String>` | No       | Tools denied to this agent           |
| `model`                    | `String`        | No       | Model override for this agent        |
| `mcp_servers`              | `Hash`          | No       | MCP servers for this agent           |
| `critical_system_reminder` | `String`        | No       | Critical reminder appended to prompt |
| `skills`                   | `Array<String>` | No       | Skills available to this agent       |
| `max_turns`                | `Integer`       | No       | Max turns for this agent             |

---

## Environment Variables

The SDK sets and reads several environment variables.

### Set by the SDK

These are automatically set in the CLI process environment via `Options#to_env`:

| Variable                                    | Value           | Description                                    |
|---------------------------------------------|-----------------|------------------------------------------------|
| `CLAUDE_CODE_ENTRYPOINT`                    | `"sdk-rb"`      | Identifies the SDK to the CLI                  |
| `CLAUDE_AGENT_SDK_VERSION`                  | Current version | SDK version string (e.g., `"0.7.15"`)          |
| `CLAUDE_CODE_ENABLE_SDK_FILE_CHECKPOINTING` | `"true"`        | Set when `enable_file_checkpointing` is true   |
| `PWD`                                       | `cwd` value     | Working directory override (when `cwd` is set) |

### Read by the SDK

These environment variables influence SDK behavior at runtime:

| Variable                              | Effect                                                                                                                                     |
|---------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------|
| `CLAUDE_AGENT_DEBUG`                  | When set (any truthy value), enables debug-level logging to stderr automatically at boot. Equivalent to calling `ClaudeAgent.debug!`.      |
| `CLAUDE_AGENT_SDK_SKIP_VERSION_CHECK` | When set to `"true"`, skips the CLI version check that runs before spawning the subprocess. Useful in CI or when using a custom CLI build. |

### Passing custom environment variables

Use the `env` option to pass additional environment variables to the CLI process:

```ruby
ClaudeAgent.configure do |c|
  c.env = {
    "ANTHROPIC_API_KEY" => "sk-...",
    "MY_CUSTOM_VAR" => "value"
  }
end

# Or per-request
turn = ClaudeAgent.ask("Hello", env: { "CUSTOM" => "value" })
```

### Debug logging

Three ways to enable debug logging:

```ruby
# 1. Environment variable (auto-detected at boot)
# CLAUDE_AGENT_DEBUG=1 ruby my_script.rb

# 2. Convenience method
ClaudeAgent.debug!
ClaudeAgent.debug!(output: File.open("debug.log", "a"))

# 3. Custom logger
ClaudeAgent.logger = Logger.new($stderr, level: :debug)
```
