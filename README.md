# ClaudeAgent

Ruby gem for building AI-powered applications with the [Claude Agent SDK](https://platform.claude.com/docs/en/agent-sdk/overview). This library essentially wraps the Claude Code CLI, providing both simple one-shot queries and interactive bidirectional sessions.

## Requirements

- Ruby 3.2+ (uses `Data.define`)
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code/getting-started) v2.0.0+

## Installation

Add to your Gemfile:

```ruby
gem "claude_agent"
```

Then run:

```bash
bundle install
```

Or install directly:

```bash
gem install claude_agent
```

## Quick Start

### One-Shot Query

The simplest way to use Claude:

```ruby
require "claude_agent"

ClaudeAgent.query(prompt: "What is the capital of France?").each do |message|
  case message
  when ClaudeAgent::AssistantMessage
    puts message.text
  when ClaudeAgent::ResultMessage
    puts "Cost: $#{message.total_cost_usd}"
  end
end
```

### Interactive Client

For multi-turn conversations:

```ruby
require "claude_agent"

ClaudeAgent::Client.open do |client|
  client.query("Remember the number 42")
  client.receive_response.each { |msg| }  # Process first response

  client.query("What number did I ask you to remember?")
  client.receive_response.each do |msg|
    puts msg.text if msg.is_a?(ClaudeAgent::AssistantMessage)
  end
end
```

## Configuration

Use `ClaudeAgent::Options` to customize behavior:

```ruby
options = ClaudeAgent::Options.new(
  # Model selection
  model: "claude-sonnet-4-5-20250514",
  fallback_model: "claude-haiku-3-5-20241022",

  # Conversation limits
  max_turns: 10,
  max_budget_usd: 1.0,
  max_thinking_tokens: 10000,

  # System prompt
  system_prompt: "You are a helpful coding assistant.",
  append_system_prompt: "Always be concise.",

  # Tool configuration
  tools: ["Read", "Write", "Bash"],
  allowed_tools: ["Read"],
  disallowed_tools: ["Write"],

  # Permission modes: "default", "acceptEdits", "plan", "delegate", "dontAsk", "bypassPermissions"
  permission_mode: "acceptEdits",

  # Working directory for file operations
  cwd: "/path/to/project",
  add_dirs: ["/additional/path"],

  # Agent configuration
  agent: "my-agent",  # Agent name for main thread

  # Session management
  resume: "session-id",
  continue_conversation: true,
  fork_session: true,
  persist_session: true,  # Default: true

  # Structured output
  output_format: {
    type: "object",
    properties: { answer: { type: "string" } }
  }
)

ClaudeAgent.query(prompt: "Help me refactor this code", options: options)
```

### Tools Preset

Use a preset tool configuration:

```ruby
# Using ToolsPreset class
options = ClaudeAgent::Options.new(
  tools: ClaudeAgent::ToolsPreset.new(preset: "claude_code")
)

# Or as a Hash
options = ClaudeAgent::Options.new(
  tools: { type: "preset", preset: "claude_code" }
)
```

### Sandbox Settings

Configure sandboxed command execution:

```ruby
sandbox = ClaudeAgent::SandboxSettings.new(
  enabled: true,
  auto_allow_bash_if_sandboxed: true,
  excluded_commands: ["docker", "kubectl"],
  network: ClaudeAgent::SandboxNetworkConfig.new(
    allowed_domains: ["api.example.com"],
    allow_local_binding: true
  ),
  ripgrep: ClaudeAgent::SandboxRipgrepConfig.new(
    command: "/usr/local/bin/rg"
  )
)

options = ClaudeAgent::Options.new(sandbox: sandbox)
```

### Custom Agents

Define custom subagents:

```ruby
agents = {
  "test-runner" => ClaudeAgent::AgentDefinition.new(
    description: "Runs tests and reports results",
    prompt: "You are a test runner. Execute tests and report failures clearly.",
    tools: ["Read", "Bash"],
    model: "haiku"
  )
}

options = ClaudeAgent::Options.new(agents: agents)
```

## Message Types

The SDK provides strongly-typed message classes:

### AssistantMessage

Claude's responses:

```ruby
message.text      # Combined text content
message.thinking  # Extended thinking content (if enabled)
message.model     # Model that generated the response
message.uuid      # Message UUID
message.session_id # Session identifier
message.tool_uses # Array of ToolUseBlock if Claude wants to use tools
message.has_tool_use?  # Check if tools are being used
```

### ResultMessage

Final message with usage statistics:

```ruby
result.session_id      # Session identifier
result.num_turns       # Number of conversation turns
result.duration_ms     # Total duration in milliseconds
result.total_cost_usd  # API cost in USD
result.usage           # Token usage breakdown
result.model_usage     # Per-model usage breakdown
result.is_error        # Whether the session ended in error
result.success?        # Convenience method
result.error?          # Convenience method
result.errors          # Array of error messages (if any)
result.permission_denials  # Array of SDKPermissionDenial (if any)
```

### SystemMessage

Internal system events:

```ruby
system_msg.subtype  # e.g., "init"
system_msg.data     # Event-specific data
```

### StreamEvent

Real-time streaming events:

```ruby
event.uuid        # Event UUID
event.session_id  # Session identifier
event.event_type  # Type of stream event
event.event       # Raw event data
```

### CompactBoundaryMessage

Conversation compaction marker:

```ruby
boundary.uuid       # Message UUID
boundary.session_id # Session identifier
boundary.trigger    # "manual" or "auto"
boundary.pre_tokens # Token count before compaction
```

### StatusMessage

Session status updates:

```ruby
status.uuid       # Message UUID
status.session_id # Session identifier
status.status     # e.g., "compacting"
```

### ToolProgressMessage

Long-running tool progress:

```ruby
progress.tool_use_id         # Tool use ID
progress.tool_name           # Tool name
progress.elapsed_time_seconds # Time elapsed
```

### HookResponseMessage

Hook execution output:

```ruby
hook_response.hook_name  # Hook name
hook_response.hook_event # Hook event type
hook_response.stdout     # Hook stdout
hook_response.stderr     # Hook stderr
hook_response.exit_code  # Exit code
```

### AuthStatusMessage

Authentication status during login:

```ruby
auth.is_authenticating # Whether auth is in progress
auth.output            # Auth output messages
auth.error             # Error message (if any)
```

## Content Blocks

Assistant messages contain content blocks:

```ruby
message.content.each do |block|
  case block
  when ClaudeAgent::TextBlock
    puts block.text
  when ClaudeAgent::ThinkingBlock
    puts "Thinking: #{block.thinking}"
  when ClaudeAgent::ToolUseBlock
    puts "Tool: #{block.name}, ID: #{block.id}, Input: #{block.input}"
  when ClaudeAgent::ToolResultBlock
    puts "Result for #{block.tool_use_id}: #{block.content}"
  when ClaudeAgent::ServerToolUseBlock
    puts "MCP Tool: #{block.name} from #{block.server_name}"
  when ClaudeAgent::ServerToolResultBlock
    puts "MCP Result from #{block.server_name}"
  when ClaudeAgent::ImageContentBlock
    puts "Image: #{block.media_type}, source: #{block.source_type}"
  end
end
```

## MCP Tools

Create in-process MCP tools that Claude can use:

```ruby
# Define a tool
calculator = ClaudeAgent::MCP::Tool.new(
  name: "add",
  description: "Add two numbers together",
  schema: { a: Float, b: Float }
) do |args|
  args["a"] + args["b"]
end

# Create a server with tools
server = ClaudeAgent::MCP::Server.new(
  name: "calculator",
  tools: [calculator]
)

# Use with options (SDK MCP servers)
options = ClaudeAgent::Options.new(
  mcp_servers: {
    "calculator" => { type: "sdk", instance: server }
  }
)

ClaudeAgent.query(
  prompt: "What is 25 + 17?",
  options: options
)
```

### External MCP Servers

Configure external MCP servers:

```ruby
options = ClaudeAgent::Options.new(
  mcp_servers: {
    "filesystem" => {
      type: "stdio",
      command: "npx",
      args: ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"]
    }
  }
)
```

### Tool Schema

Define schemas using Ruby types or JSON Schema:

```ruby
# Ruby types (converted automatically)
schema: {
  name: String,
  age: Integer,
  score: Float,
  active: TrueClass,  # boolean
  tags: Array,
  metadata: Hash
}

# Or use JSON Schema directly
schema: {
  type: "object",
  properties: {
    name: { type: "string", description: "User's name" },
    age: { type: "integer", minimum: 0 }
  },
  required: ["name"]
}
```

### Tool Return Values

Tools can return various formats:

```ruby
# Simple string
ClaudeAgent::MCP::Tool.new(name: "greet", description: "Greet") do |args|
  "Hello, #{args['name']}!"
end

# Number (converted to string)
ClaudeAgent::MCP::Tool.new(name: "add", description: "Add") do |args|
  args["a"] + args["b"]
end

# Custom MCP content
ClaudeAgent::MCP::Tool.new(name: "fancy", description: "Fancy") do |args|
  { content: [{ type: "text", text: "Custom response" }] }
end
```

## Hooks

Intercept tool usage and other events with hooks:

```ruby
options = ClaudeAgent::Options.new(
  hooks: {
    "PreToolUse" => [
      ClaudeAgent::HookMatcher.new(
        matcher: "Bash|Write",  # Match specific tools
        callbacks: [
          ->(input, context) {
            puts "Tool: #{input.tool_name}"
            puts "Input: #{input.tool_input}"
            puts "Tool Use ID: #{input.tool_use_id}"
            { continue_: true }  # Allow the tool to proceed
          }
        ]
      )
    ],
    "PostToolUse" => [
      ClaudeAgent::HookMatcher.new(
        matcher: /^mcp__/,  # Regex matching
        callbacks: [
          ->(input, context) {
            puts "Result: #{input.tool_response}"
            { continue_: true }
          }
        ]
      )
    ]
  }
)
```

### Hook Events

All available hook events:

- `PreToolUse` - Before tool execution
- `PostToolUse` - After successful tool execution
- `PostToolUseFailure` - After tool execution failure
- `Notification` - System notifications
- `UserPromptSubmit` - When user submits a prompt
- `SessionStart` - When session starts
- `SessionEnd` - When session ends
- `Stop` - When agent stops
- `SubagentStart` - When subagent starts
- `SubagentStop` - When subagent stops
- `PreCompact` - Before conversation compaction
- `PermissionRequest` - When permission is requested

### Hook Input Types

| Event              | Input Type                | Key Fields                                              |
|--------------------|---------------------------|---------------------------------------------------------|
| PreToolUse         | `PreToolUseInput`         | tool_name, tool_input, tool_use_id                      |
| PostToolUse        | `PostToolUseInput`        | tool_name, tool_input, tool_response, tool_use_id       |
| PostToolUseFailure | `PostToolUseFailureInput` | tool_name, tool_input, error, tool_use_id, is_interrupt |
| Notification       | `NotificationInput`       | message, title, notification_type                       |
| UserPromptSubmit   | `UserPromptSubmitInput`   | prompt                                                  |
| SessionStart       | `SessionStartInput`       | source, agent_type, model                               |
| SessionEnd         | `SessionEndInput`         | reason                                                  |
| Stop               | `StopInput`               | stop_hook_active                                        |
| SubagentStart      | `SubagentStartInput`      | agent_id, agent_type                                    |
| SubagentStop       | `SubagentStopInput`       | stop_hook_active, agent_id, agent_transcript_path       |
| PreCompact         | `PreCompactInput`         | trigger, custom_instructions                            |
| PermissionRequest  | `PermissionRequestInput`  | tool_name, tool_input, permission_suggestions           |

All hook inputs inherit from `BaseHookInput` with: `hook_event_name`, `session_id`, `transcript_path`, `cwd`, `permission_mode`.

## Permissions

Control tool permissions programmatically:

```ruby
options = ClaudeAgent::Options.new(
  can_use_tool: ->(tool_name, tool_input, context) {
    # Context includes: permission_suggestions, blocked_path, decision_reason, tool_use_id, agent_id

    # Allow all read operations
    if tool_name == "Read"
      ClaudeAgent::PermissionResultAllow.new
    # Deny writes to sensitive paths
    elsif tool_name == "Write" && tool_input["file_path"].include?(".env")
      ClaudeAgent::PermissionResultDeny.new(
        message: "Cannot modify .env files",
        interrupt: true
      )
    else
      ClaudeAgent::PermissionResultAllow.new
    end
  }
)
```

### Permission Results

```ruby
# Allow with optional modifications
ClaudeAgent::PermissionResultAllow.new(
  updated_input: { file_path: "/safe/path" },  # Modify tool input
  updated_permissions: [...]  # Update permission rules
)

# Deny
ClaudeAgent::PermissionResultDeny.new(
  message: "Operation not allowed",
  interrupt: true  # Stop the agent
)
```

### Permission Updates

```ruby
update = ClaudeAgent::PermissionUpdate.new(
  type: "addRules",  # addRules, replaceRules, removeRules, setMode, addDirectories, removeDirectories
  rules: [
    ClaudeAgent::PermissionRuleValue.new(tool_name: "Read", rule_content: "/**")
  ],
  behavior: "allow",
  destination: "session"  # userSettings, projectSettings, localSettings, session, cliArg
)
```

## Error Handling

The SDK provides specific error types:

```ruby
begin
  ClaudeAgent.query(prompt: "Hello")
rescue ClaudeAgent::CLINotFoundError
  puts "Claude Code CLI not installed"
rescue ClaudeAgent::CLIVersionError => e
  puts "CLI version too old: #{e.message}"
  puts "Required: #{e.required_version}, Actual: #{e.actual_version}"
rescue ClaudeAgent::CLIConnectionError => e
  puts "Connection failed: #{e.message}"
rescue ClaudeAgent::ProcessError => e
  puts "Process error: #{e.message}, exit code: #{e.exit_code}"
rescue ClaudeAgent::TimeoutError => e
  puts "Timeout: #{e.message}"
rescue ClaudeAgent::JSONDecodeError => e
  puts "Invalid JSON response"
rescue ClaudeAgent::MessageParseError => e
  puts "Could not parse message"
rescue ClaudeAgent::AbortError => e
  puts "Operation aborted"
end
```

## Client API

For fine-grained control:

```ruby
client = ClaudeAgent::Client.new(options: options)

# Connect to CLI
client.connect

# Send queries
client.query("First question")
client.receive_response.each { |msg| process(msg) }

client.query("Follow-up question")
client.receive_response.each { |msg| process(msg) }

# Control methods
client.interrupt                              # Cancel current operation
client.set_model("claude-opus-4-5-20251101")  # Change model
client.set_permission_mode("acceptEdits")     # Change permissions
client.set_max_thinking_tokens(5000)          # Change thinking limit

# File checkpointing (requires enable_file_checkpointing: true)
result = client.rewind_files("user-message-uuid", dry_run: true)
puts "Can rewind: #{result.can_rewind}"
puts "Files changed: #{result.files_changed}"

# Dynamic MCP server management
result = client.set_mcp_servers({
  "my-server" => { type: "stdio", command: "node", args: ["server.js"] }
})
puts "Added: #{result.added}, Removed: #{result.removed}"

# Query capabilities
client.supported_commands.each { |cmd| puts "#{cmd.name}: #{cmd.description}" }
client.supported_models.each { |model| puts "#{model.value}: #{model.display_name}" }
client.mcp_server_status.each { |s| puts "#{s.name}: #{s.status}" }
puts client.account_info.email

# Disconnect
client.disconnect
```

## V2 Session API (Unstable)

> **⚠️ Alpha API**: This API is unstable and may change without notice.

The V2 Session API provides a simpler interface for multi-turn conversations, matching the TypeScript SDK's `SDKSession` interface.

### Create a Session

```ruby
# Create a new session
session = ClaudeAgent.unstable_v2_create_session(
  model: "claude-sonnet-4-5-20250514",
  permission_mode: "acceptEdits"
)

# Send a message
session.send("Hello, Claude!")

# Stream responses
session.stream.each do |msg|
  case msg
  when ClaudeAgent::AssistantMessage
    puts msg.text
  when ClaudeAgent::ResultMessage
    puts "Done! Cost: $#{msg.total_cost_usd}"
  end
end

# Continue the conversation
session.send("Tell me more")
session.stream.each { |msg| puts msg.text if msg.is_a?(ClaudeAgent::AssistantMessage) }

# Close when done
session.close
```

### Resume a Session

```ruby
# Resume an existing session by ID
session = ClaudeAgent.unstable_v2_resume_session(
  "session-abc123",
  model: "claude-sonnet-4-5-20250514"
)

session.send("What were we discussing?")
session.stream.each { |msg| puts msg.text if msg.is_a?(ClaudeAgent::AssistantMessage) }
session.close
```

### One-Shot Prompt

```ruby
# Simple one-shot prompt (auto-closes session)
result = ClaudeAgent.unstable_v2_prompt(
  "What is 2 + 2?",
  model: "claude-sonnet-4-5-20250514"
)

puts "Success: #{result.success?}"
puts "Cost: $#{result.total_cost_usd}"
```

### SessionOptions

The V2 API uses a simplified options type:

```ruby
options = ClaudeAgent::SessionOptions.new(
  model: "claude-sonnet-4-5-20250514",           # Required
  permission_mode: "acceptEdits",                 # Optional
  allowed_tools: ["Read", "Grep"],                # Optional
  disallowed_tools: ["Write"],                    # Optional
  can_use_tool: ->(name, input, ctx) { ... },    # Optional
  hooks: { "PreToolUse" => [...] },               # Optional
  env: { "MY_VAR" => "value" },                   # Optional
  path_to_claude_code_executable: "/custom/path"  # Optional
)

session = ClaudeAgent.unstable_v2_create_session(options)
```

## Types Reference

### Return Types

| Type                  | Purpose                                                                          |
|-----------------------|----------------------------------------------------------------------------------|
| `SlashCommand`        | Available slash commands (name, description, argument_hint)                      |
| `ModelInfo`           | Available models (value, display_name, description)                              |
| `McpServerStatus`     | MCP server status (name, status, server_info)                                    |
| `AccountInfo`         | Account information (email, organization, subscription_type)                     |
| `ModelUsage`          | Per-model usage stats (input_tokens, output_tokens, cost_usd)                    |
| `McpSetServersResult` | Result of set_mcp_servers (added, removed, errors)                               |
| `RewindFilesResult`   | Result of rewind_files (can_rewind, error, files_changed, insertions, deletions) |
| `SDKPermissionDenial` | Permission denial info (tool_name, tool_use_id, tool_input)                      |

## Environment Variables

The SDK sets these automatically:

- `CLAUDE_CODE_ENTRYPOINT=sdk-rb`
- `CLAUDE_AGENT_SDK_VERSION=<version>`

Skip version checking (for development):

```bash
export CLAUDE_AGENT_SDK_SKIP_VERSION_CHECK=true
```

## Development

```bash
# Install dependencies
bin/setup

# Run unit tests
bundle exec rake test

# Run integration tests (requires Claude Code CLI v2.0.0+)
bundle exec rake test_integration

# Run all tests
bundle exec rake test_all

# Validate RBS type signatures
bundle exec rake rbs

# Linting
bundle exec rubocop

# Interactive console
bin/console

# Binstubs for convenience
bin/test              # Unit tests only
bin/test-integration  # Integration tests
bin/test-all          # All tests
bin/rbs-validate      # Validate RBS signatures
bin/release 1.2.0     # Release a new version
```

## Architecture

```
ClaudeAgent.query() / ClaudeAgent::Client
           │
           ▼
┌──────────────────────────┐
│   Control Protocol       │  Request/response routing
│   - Hooks                │  Permission callbacks
│   - MCP bridging         │  Tool interception
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│   Subprocess Transport   │  JSON Lines protocol
│   - stdin/stdout         │  Process management
│   - stderr handling      │
└──────────┬───────────────┘
           │
           ▼
     Claude Code CLI
```

## License

MIT License - see [LICENSE.txt](LICENSE.txt)
