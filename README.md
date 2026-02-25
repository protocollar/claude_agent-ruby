# ClaudeAgent

Ruby gem for building AI-powered applications with the [Claude Agent SDK](https://platform.claude.com/docs/en/agent-sdk/overview). This library essentially wraps the Claude Code CLI, providing both simple one-shot queries and interactive bidirectional sessions.

## Requirements

- Ruby 3.2+ (uses `Data.define`)
- [Claude Code CLI](https://code.claude.com/docs/en/getting-started) v2.0.0+

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

### Conversation (Recommended)

The simplest way to have multi-turn conversations:

```ruby
require "claude_agent"

ClaudeAgent::Conversation.open(
  permission_mode: "acceptEdits",
  on_stream: ->(text) { print text }
) do |c|
  c.say("Fix the bug in auth.rb")
  c.say("Now add tests for the fix")
  puts "\nTotal cost: $#{c.total_cost}"
end
```

### One-Shot Query

For single questions:

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

### One-Shot with TurnResult

Get a structured result without writing `case` statements:

```ruby
require "claude_agent"

turn = ClaudeAgent.query_turn(prompt: "What is the capital of France?")
puts turn.text
puts "Cost: $#{turn.cost}"
puts "Model: #{turn.model}"
```

### Interactive Client

For fine-grained control over the conversation:

```ruby
require "claude_agent"

ClaudeAgent::Client.open do |client|
  client.on_text { |text| print text }

  turn = client.send_and_receive("Remember the number 42")
  turn = client.send_and_receive("What number did I ask you to remember?")

  puts "\nAnswer: #{turn.text}"
end
```

### Run Setup Hooks

Run Setup hooks without starting a conversation (useful for CI/CD pipelines):

```ruby
require "claude_agent"

# Run init Setup hooks (default)
messages = ClaudeAgent.run_setup
result = messages.last
puts "Setup completed" if result.success?

# Run init Setup hooks with custom options
options = ClaudeAgent::Options.new(cwd: "/my/project")
ClaudeAgent.run_setup(trigger: :init, options: options)

# Run maintenance Setup hooks
ClaudeAgent.run_setup(trigger: :maintenance)
```

## Conversation API

The `Conversation` class manages the full lifecycle: auto-connects on first message, tracks multi-turn history, accumulates usage, and builds a unified tool activity timeline.

### Basic Usage

```ruby
conversation = ClaudeAgent.conversation(
  model: "claude-sonnet-4-5-20250514",
  permission_mode: "acceptEdits",
  on_text: ->(text) { print text }
)

turn = conversation.say("Help me refactor this module")
puts turn.tool_uses.map(&:display_label)  # ["Read lib/foo.rb", "Edit lib/foo.rb"]

turn = conversation.say("Now update the tests")
puts "Session cost: $#{conversation.total_cost}"

conversation.close
```

### Block Form

Automatically cleans up when the block exits:

```ruby
ClaudeAgent::Conversation.open(
  max_turns: 10,
  on_tool_use: ->(tool) { puts "  Using: #{tool.display_label}" }
) do |c|
  c.say("Implement the feature described in SPEC.md")
  c.say("Run the tests and fix any failures")

  puts "Tools used: #{c.tool_activity.size}"
  puts "Total cost: $#{c.total_cost}"
end
```

### Resume a Previous Session

```ruby
conversation = ClaudeAgent.resume_conversation("session-abc-123")
turn = conversation.say("Continue where we left off")
conversation.close
```

### Callbacks

Register callbacks for real-time event handling:

```ruby
conversation = ClaudeAgent.conversation(
  on_text:        ->(text)    { print text },
  on_stream:      ->(text)    { print text },          # Alias for on_text
  on_thinking:    ->(thought) { puts "Thinking: #{thought}" },
  on_tool_use:    ->(tool)    { puts "Tool: #{tool.display_label}" },
  on_tool_result: ->(result)  { puts "Result: #{result.content&.slice(0, 80)}" },
  on_result:      ->(result)  { puts "Done! Cost: $#{result.total_cost_usd}" },
  on_message:     ->(msg)     { log(msg) }             # Catch-all
)
```

### Tool Activity Timeline

Track all tool executions across turns with timing:

```ruby
ClaudeAgent::Conversation.open(permission_mode: "acceptEdits") do |c|
  c.say("Refactor the auth module")

  c.tool_activity.each do |activity|
    puts "#{activity.display_label} (turn #{activity.turn_index})"
    puts "  Duration: #{activity.duration&.round(2)}s" if activity.duration
    puts "  Error!" if activity.error?
  end
end
```

### Conversation Accessors

```ruby
conversation.turns             # Array of TurnResult objects
conversation.messages          # All messages across all turns
conversation.tool_activity     # Array of ToolActivity objects
conversation.total_cost        # Total cost in USD
conversation.session_id        # Session ID from most recent turn
conversation.usage             # CumulativeUsage stats
conversation.open?             # Whether conversation is connected
conversation.closed?           # Whether conversation has been closed
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

  # Extended thinking
  thinking: { type: "enabled", budgetTokens: 10000 },   # or "adaptive" or "disabled"
  # max_thinking_tokens: 10000,                          # Shorthand (when thinking not set)

  # Response effort
  effort: "high",  # "low", "medium", "high", "max"

  # System prompt
  system_prompt: "You are a helpful coding assistant.",
  append_system_prompt: "Always be concise.",

  # Tool configuration
  tools: ["Read", "Write", "Bash"],
  allowed_tools: ["Read"],
  disallowed_tools: ["Write"],

  # Permission modes: "default", "acceptEdits", "plan", "dontAsk", "bypassPermissions"
  permission_mode: "acceptEdits",
  permission_queue: true,  # Enable queue-based permissions (see Permissions section)

  # Working directory for file operations
  cwd: "/path/to/project",
  add_dirs: ["/additional/path"],

  # Agent configuration
  agent: "my-agent",  # Agent name for main thread

  # Session management
  resume: "session-id",
  session_id: "custom-uuid",  # Custom conversation UUID
  continue_conversation: true,
  fork_session: true,
  persist_session: true,  # Default: true

  # Structured output
  output_format: {
    type: "object",
    properties: { answer: { type: "string" } }
  },

  # Prompt suggestions
  prompt_suggestions: true,

  # Debug logging (CLI-level)
  debug: true,
  debug_file: "/path/to/debug.log"
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
    allow_local_binding: true,
    allow_managed_domains_only: false
  ),
  filesystem: ClaudeAgent::SandboxFilesystemConfig.new(
    allow_write: ["/tmp/*"],
    deny_write: ["/etc/*"],
    deny_read: ["/secrets/*"]
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
    model: "haiku",
    max_turns: 5,                  # Max agentic turns before stopping
    skills: ["testing", "debug"]   # Skills to preload into agent context
  )
}

options = ClaudeAgent::Options.new(agents: agents)
```

## TurnResult

A `TurnResult` accumulates all messages from sending a prompt to receiving the final `ResultMessage`. It eliminates the need for `case` statements over raw message types.

### Getting a TurnResult

```ruby
# Via Conversation
turn = conversation.say("Fix the bug")

# Via Client
turn = client.send_and_receive("Fix the bug")

# Via one-shot query
turn = ClaudeAgent.query_turn(prompt: "Fix the bug")
```

### Accessors

```ruby
# Text and thinking
turn.text                # All text content concatenated
turn.thinking            # All thinking content concatenated

# Tool usage
turn.tool_uses           # Array of ToolUseBlock / ServerToolUseBlock
turn.tool_results        # Array of ToolResultBlock / ServerToolResultBlock
turn.tool_executions     # Array of { tool_use:, tool_result: } pairs

# Result data
turn.cost                # Total cost in USD
turn.duration_ms         # Wall-clock duration
turn.session_id          # Session ID for resumption
turn.model               # Model name
turn.stop_reason         # Why the model stopped ("end_turn", "tool_use", etc.)
turn.usage               # Token usage hash
turn.model_usage         # Per-model usage breakdown
turn.structured_output   # Structured output (if requested)
turn.num_turns           # Number of turns in session

# Status
turn.success?            # Whether turn completed successfully
turn.error?              # Whether turn ended with error
turn.complete?           # Whether a ResultMessage was received
turn.errors              # Array of error strings
turn.permission_denials  # Array of SDKPermissionDenial

# Filtered message access
turn.assistant_messages  # All AssistantMessages
turn.user_messages       # All UserMessages / UserMessageReplays
turn.stream_events       # All StreamEvents
turn.content_blocks      # All content blocks across assistant messages
```

## Event Handlers

Register typed callbacks instead of writing `case` statements. Works with `Client`, `Conversation`, or standalone.

### Via Client

```ruby
ClaudeAgent::Client.open do |client|
  client.on_text { |text| print text }
  client.on_tool_use { |tool| puts "\nUsing: #{tool.display_label}" }
  client.on_tool_result { |result, tool_use| puts "Done: #{tool_use&.name}" }
  client.on_result { |result| puts "\nCost: $#{result.total_cost_usd}" }

  client.send_and_receive("Fix the bug in auth.rb")
end
```

### Via One-Shot Query

```ruby
events = ClaudeAgent::EventHandler.new
  .on_text { |text| print text }
  .on_result { |r| puts "\nDone!" }

ClaudeAgent.query_turn(prompt: "Explain this code", events: events)
```

### Standalone

```ruby
handler = ClaudeAgent::EventHandler.new
handler.on(:text) { |text| print text }
handler.on(:thinking) { |thought| puts "Thinking: #{thought}" }
handler.on(:tool_use) { |tool| puts "Tool: #{tool.display_label}" }
handler.on(:tool_result) { |result, tool_use| puts "Result for #{tool_use&.name}" }
handler.on(:result) { |result| puts "Cost: $#{result.total_cost_usd}" }
handler.on(:message) { |msg| log(msg) }  # Catch-all

# Dispatch manually
client.receive_response.each { |msg| handler.handle(msg) }
handler.reset!  # Clear turn state between turns
```

## Message Types

The SDK provides strongly-typed message classes for all protocol messages.

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
result.stop_reason     # Why the model stopped generating (e.g. "end_turn", "tool_use")
```

### UserMessageReplay

Replayed user messages when resuming a session with existing history:

```ruby
replay.content             # Message content
replay.uuid                # Message UUID
replay.session_id          # Session identifier
replay.parent_tool_use_id  # Parent tool use ID (if tool result)
replay.replay?             # true if this is a replayed message
replay.synthetic?          # true if this is a synthetic message
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
hook_response.hook_id    # Hook identifier
hook_response.hook_name  # Hook name
hook_response.hook_event # Hook event type
hook_response.stdout     # Hook stdout
hook_response.stderr     # Hook stderr
hook_response.output     # Combined output
hook_response.exit_code  # Exit code
hook_response.outcome    # "success", "error", or "cancelled"
hook_response.success?   # Convenience predicate
hook_response.error?     # Convenience predicate
hook_response.cancelled? # Convenience predicate
```

### HookStartedMessage

Hook execution start notification:

```ruby
hook_started.hook_id    # Hook identifier
hook_started.hook_name  # Hook name
hook_started.hook_event # Hook event type
```

### HookProgressMessage

Progress during hook execution:

```ruby
hook_progress.hook_id    # Hook identifier
hook_progress.hook_name  # Hook name
hook_progress.hook_event # Hook event type
hook_progress.stdout     # Hook stdout so far
hook_progress.stderr     # Hook stderr so far
hook_progress.output     # Combined output
```

### ToolUseSummaryMessage

Summary of tool use for collapsed display:

```ruby
summary.summary                  # Human-readable summary text
summary.preceding_tool_use_ids   # Tool use IDs this summarizes
```

### FilesPersistedEvent

Files persisted to storage during a session:

```ruby
persisted.files        # Array of successfully persisted file paths
persisted.failed       # Array of files that failed to persist
persisted.processed_at # Timestamp of persistence
```

### AuthStatusMessage

Authentication status during login:

```ruby
auth.is_authenticating # Whether auth is in progress
auth.output            # Auth output messages
auth.error             # Error message (if any)
```

### TaskNotificationMessage

Background task completion notifications:

```ruby
notification.task_id     # Background task ID
notification.status      # "completed", "failed", or "stopped"
notification.output_file # Path to task output file
notification.summary     # Task summary
notification.completed?  # Convenience predicate
notification.failed?     # Convenience predicate
notification.stopped?    # Convenience predicate
```

### TaskStartedMessage

Background task (subagent) start notification:

```ruby
task_started.task_id      # Task ID
task_started.tool_use_id  # Associated tool use ID (optional)
task_started.description  # Task description (optional)
task_started.task_type    # Task type (optional)
```

### TaskProgressMessage

Background task progress reporting:

```ruby
task_progress.task_id        # Task ID
task_progress.description    # What the task is doing
task_progress.usage          # Token usage so far (optional)
task_progress.last_tool_name # Most recent tool used (optional)
```

### RateLimitEvent

Rate limit status and utilization:

```ruby
rate_limit.rate_limit_info  # Full rate limit info hash
rate_limit.status           # Rate limit status (e.g. "allowed_warning")
```

### PromptSuggestionMessage

Suggested follow-up prompts (requires `prompt_suggestions: true`):

```ruby
suggestion.suggestion  # The suggested prompt text
```

### GenericMessage

Wraps unknown/future message types instead of raising errors:

```ruby
msg.type       # Message type as symbol (e.g. :fancy_new)
msg[:data]     # Dynamic field access via []
msg.data       # Dynamic field access via method_missing
msg.to_h       # Raw data hash
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
    puts "Tool: #{block.display_label}"
    puts "  File: #{block.file_path}" if block.file_path
    puts "  Summary: #{block.summary}"
  when ClaudeAgent::ToolResultBlock
    puts "Result for #{block.tool_use_id}: #{block.content}"
  when ClaudeAgent::ServerToolUseBlock
    puts "MCP Tool: #{block.display_label}"  # "server_name/tool_name"
  when ClaudeAgent::ServerToolResultBlock
    puts "MCP Result from #{block.server_name}"
  when ClaudeAgent::ImageContentBlock
    puts "Image: #{block.media_type}, source: #{block.source_type}"
  when ClaudeAgent::GenericBlock
    puts "Unknown block: #{block.type}, data: #{block.to_h}"
  end
end
```

### ToolUseBlock Introspection

Tool use blocks provide human-readable labels and summaries:

```ruby
block.name          # "Read", "Write", "Bash", etc.
block.input         # Tool input parameters (symbol-keyed Hash)
block.file_path     # File path for Read/Write/Edit/NotebookEdit (nil otherwise)
block.display_label # One-line label: "Read lib/foo.rb", "Bash: git status", "Grep: pattern"
block.summary       # Detailed: "Write: /path.rb (3 lines)", "Edit: /path.rb replacing 5 line(s)"
block.summary(max: 100)  # Custom max length
```

`ServerToolUseBlock` provides the same interface with server context in labels (e.g. `"calculator/add"`).

### GenericBlock

Unknown content block types are wrapped instead of returning raw Hashes:

```ruby
block.type     # Block type as symbol
block[:field]  # Dynamic field access via []
block.field    # Dynamic field access via method_missing
block.to_h     # Raw data hash
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
  args[:a] + args[:b]
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

> **Note:** MCP tool handlers receive **symbol-keyed** argument hashes (e.g. `args[:a]` not `args["a"]`).

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

### Tool Annotations

Annotate tools with hints about their behavior:

```ruby
tool = ClaudeAgent::MCP::Tool.new(
  name: "search",
  description: "Search the web",
  schema: { query: String },
  annotations: {
    readOnlyHint: true,       # Tool only reads data, no side effects
    destructiveHint: false,   # Tool does not destroy/delete data
    idempotentHint: true,     # Repeated calls with same args have same effect
    openWorldHint: true,      # Tool interacts with external systems
    title: "Web Search"       # Human-readable display name
  }
) { |args| "Results for #{args[:query]}" }

# Or with the convenience method
tool = ClaudeAgent::MCP.tool(
  "search", "Search the web", { query: String },
  annotations: { readOnlyHint: true, openWorldHint: true }
) { |args| "Results" }
```

All annotation fields are optional hints — omit any that don't apply.

### Tool Return Values

Tools can return various formats:

```ruby
# Simple string
ClaudeAgent::MCP::Tool.new(name: "greet", description: "Greet") do |args|
  "Hello, #{args[:name]}!"
end

# Number (converted to string)
ClaudeAgent::MCP::Tool.new(name: "add", description: "Add") do |args|
  args[:a] + args[:b]
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

> **Note:** Hook callbacks receive **symbol-keyed** input hashes (e.g. `input.tool_input[:file_path]`).

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
- `Setup` - Initial setup or maintenance (trigger: "init" or "maintenance")
- `TeammateIdle` - When a teammate agent becomes idle
- `TaskCompleted` - When a background task completes
- `ConfigChange` - When configuration changes
- `WorktreeCreate` - When a git worktree is created
- `WorktreeRemove` - When a git worktree is removed

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
| Setup              | `SetupInput`              | trigger (init/maintenance)                              |
| TeammateIdle       | `TeammateIdleInput`       | teammate_name, team_name                                |
| TaskCompleted      | `TaskCompletedInput`      | task_id, task_subject, task_description, teammate_name  |
| ConfigChange       | `ConfigChangeInput`       | source, file_path                                       |
| WorktreeCreate     | `WorktreeCreateInput`     | name                                                    |
| WorktreeRemove     | `WorktreeRemoveInput`     | worktree_path                                           |

All hook inputs inherit from `BaseHookInput` with: `hook_event_name`, `session_id`, `transcript_path`, `cwd`, `permission_mode`.

## Permissions

Control tool permissions programmatically:

```ruby
options = ClaudeAgent::Options.new(
  can_use_tool: ->(tool_name, tool_input, context) {
    # Context includes: permission_suggestions, blocked_path, decision_reason,
    #                   tool_use_id, agent_id, description

    # Allow all read operations
    if tool_name == "Read"
      ClaudeAgent::PermissionResultAllow.new
    # Deny writes to sensitive paths
    elsif tool_name == "Write" && tool_input[:file_path]&.include?(".env")
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

> **Note:** `can_use_tool` callbacks receive **symbol-keyed** `tool_input` hashes.

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

### Permission Queue

For UI-driven permission handling (e.g. TUI's, desktop apps, web UIs), use queue-based permissions instead of synchronous callbacks:

```ruby
# Enable via Options
options = ClaudeAgent::Options.new(permission_queue: true)

# Or via Conversation (queue mode is the default)
conversation = ClaudeAgent.conversation(permission_mode: "default")
```

Resolve permissions from any thread:

```ruby
# Non-blocking poll
if request = client.pending_permission
  puts "Tool: #{request.tool_name}"
  puts "Input: #{request.input}"
  request.allow!  # or request.deny!(message: "Not allowed")
end

# Check if any are waiting
client.pending_permissions?

# Blocking wait with timeout
request = client.permission_queue.pop(timeout: 30)
request&.allow!

# Drain all pending (e.g. during shutdown)
client.permission_queue.drain!(reason: "Session ended")
```

### Hybrid Mode

Combine synchronous callbacks with deferred queue resolution:

```ruby
options = ClaudeAgent::Options.new(
  can_use_tool: ->(tool_name, tool_input, context) {
    if tool_name == "Read"
      ClaudeAgent::PermissionResultAllow.new  # Auto-allow reads
    else
      context.request.defer!  # Defer everything else to the queue
    end
  }
)

client = ClaudeAgent::Client.new(options: options)
client.connect

# In another thread: resolve deferred permissions
Thread.new do
  loop do
    request = client.permission_queue.pop
    break unless request
    request.allow!  # Or show UI dialog
  end
end
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

## Cumulative Usage

The `Client` automatically tracks cumulative usage across turns:

```ruby
ClaudeAgent::Client.open do |client|
  client.send_and_receive("Hello")
  client.send_and_receive("Follow up")

  usage = client.cumulative_usage
  puts "Tokens: #{usage.input_tokens} in / #{usage.output_tokens} out"
  puts "Cache: #{usage.cache_read_input_tokens} read / #{usage.cache_creation_input_tokens} created"
  puts "Cost: $#{usage.total_cost_usd}"
  puts "Turns: #{usage.num_turns}"
  puts "Duration: #{usage.duration_ms}ms"
end
```

Also available via `Conversation#usage`:

```ruby
ClaudeAgent::Conversation.open do |c|
  c.say("Hello")
  puts c.usage.to_h  # => { input_tokens: 100, output_tokens: 50, ... }
end
```

## Client API

For fine-grained control:

```ruby
client = ClaudeAgent::Client.new(options: options)

# Connect to CLI
client.connect

# Send queries and receive TurnResults
turn = client.send_and_receive("First question")
puts turn.text

turn = client.send_and_receive("Follow-up question")
puts turn.text

# Or use lower-level send/receive
client.send_message("Question")
client.receive_response.each { |msg| process(msg) }

# Or receive as TurnResult without sending
client.send_message("Question")
turn = client.receive_turn

# Event handlers (persist across turns)
client.on_text { |text| print text }
client.on_tool_use { |tool| puts tool.display_label }
client.on_tool_result { |result, tool_use| puts "Done: #{tool_use&.name}" }
client.on_thinking { |thought| puts thought }
client.on_result { |result| puts "Cost: $#{result.total_cost_usd}" }
client.on_message { |msg| log(msg) }

# Control methods
client.interrupt                              # Cancel current operation
client.set_model("claude-opus-4-5-20251101")  # Change model
client.set_permission_mode("acceptEdits")     # Change permissions
client.set_max_thinking_tokens(5000)          # Change thinking limit
client.stop_task("task-123")                  # Stop a running background task
client.apply_flag_settings({ "model" => "..." })  # Merge settings into flag layer

# File checkpointing (requires enable_file_checkpointing: true)
result = client.rewind_files("user-message-uuid", dry_run: true)
puts "Can rewind: #{result.can_rewind}"
puts "Files changed: #{result.files_changed}"

# Dynamic MCP server management
result = client.set_mcp_servers({
  "my-server" => { type: "stdio", command: "node", args: ["server.js"] }
})
puts "Added: #{result.added}, Removed: #{result.removed}"

# MCP server lifecycle
client.mcp_reconnect("my-server")                     # Reconnect a disconnected server
client.mcp_toggle("my-server", enabled: false)         # Disable a server
client.mcp_toggle("my-server", enabled: true)          # Re-enable a server
client.mcp_authenticate("my-remote-server")            # OAuth authentication
client.mcp_clear_auth("my-remote-server")              # Clear stored credentials

# Permission queue access
client.pending_permission    # Non-blocking poll for next request
client.pending_permissions?  # Check if any requests waiting
client.permission_queue      # Direct access to PermissionQueue

# Cumulative usage tracking
client.cumulative_usage      # CumulativeUsage with totals across all turns

# Query capabilities
client.supported_commands.each { |cmd| puts "#{cmd.name}: #{cmd.description}" }
client.supported_models.each { |model| puts "#{model.value}: #{model.display_name}" }
client.mcp_server_status.each { |s| puts "#{s.name}: #{s.status}" }
puts client.account_info.email

# Disconnect
client.disconnect
```

## Session Discovery

List past Claude Code sessions from disk without spawning a CLI subprocess:

```ruby
# All sessions (most recent first)
sessions = ClaudeAgent.list_sessions

# Scoped to a project directory (includes git worktree siblings)
sessions = ClaudeAgent.list_sessions(dir: "/path/to/project", limit: 10)

sessions.each do |s|
  puts "#{s.summary} (#{s.git_branch || 'no branch'})"
  puts "  Session: #{s.session_id}"
  puts "  Modified: #{Time.at(s.last_modified / 1000)}"
  puts "  Prompt: #{s.first_prompt}" if s.first_prompt
end
```

Each session is a `SessionInfo` with these fields:

| Field            | Type            | Description                                      |
|------------------|-----------------|--------------------------------------------------|
| `session_id`     | `String`        | UUID of the session                              |
| `summary`        | `String`        | Custom title, last summary, or first prompt      |
| `last_modified`  | `Integer`       | Epoch milliseconds of last modification          |
| `file_size`      | `Integer`       | Session file size in bytes                       |
| `custom_title`   | `String\|nil`   | User-set title, if any                           |
| `first_prompt`   | `String\|nil`   | First meaningful user prompt                     |
| `git_branch`     | `String\|nil`   | Git branch the session was on                    |
| `cwd`            | `String\|nil`   | Working directory of the session                 |

Use with `Conversation.resume` to pick up where you left off:

```ruby
sessions = ClaudeAgent.list_sessions(dir: Dir.pwd, limit: 5)
session = sessions.first

conversation = ClaudeAgent.resume_conversation(session.session_id)
turn = conversation.say("Continue where we left off")
conversation.close
```

## V2 Session API (Unstable)

> **Warning**: This API is unstable and may change without notice.

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
| `TurnResult`          | Complete agent turn with text, tools, usage, and status accessors                |
| `ToolActivity`        | Tool use/result pair with turn index and timing                                  |
| `CumulativeUsage`     | Running totals of tokens, cost, turns, and duration                              |
| `PermissionRequest`   | Deferred permission promise resolvable from any thread                           |
| `PermissionQueue`     | Thread-safe queue of pending permission requests                                 |
| `EventHandler`        | Typed event callback registry                                                    |
| `SlashCommand`        | Available slash commands (name, description, argument_hint)                      |
| `ModelInfo`           | Available models (value, display_name, description)                              |
| `McpServerStatus`     | MCP server status (name, status, server_info)                                    |
| `AccountInfo`         | Account information (email, organization, subscription_type)                     |
| `ModelUsage`          | Per-model usage stats (input_tokens, output_tokens, cost_usd)                    |
| `McpSetServersResult` | Result of set_mcp_servers (added, removed, errors)                               |
| `RewindFilesResult`   | Result of rewind_files (can_rewind, error, files_changed, insertions, deletions) |
| `SessionInfo`         | Session metadata from `list_sessions` (session_id, summary, git_branch, cwd)     |
| `SDKPermissionDenial` | Permission denial info (tool_name, tool_use_id, tool_input)                      |

## Logging

The SDK includes optional logging with zero overhead when disabled. All log output is silent by default.

### Quick Debug

```ruby
# Enable debug logging to stderr
ClaudeAgent.debug!

# Or to a file
ClaudeAgent.debug!(output: File.open("claude_agent.log", "a"))
```

### Custom Logger

Set any `Logger`-compatible instance at the module level:

```ruby
ClaudeAgent.logger = Logger.new($stderr, level: :info)
```

### Per-Query Logger

Override the module-level logger for a specific query or client:

```ruby
my_logger = Logger.new("query.log", level: :debug)

ClaudeAgent.query(prompt: "Hello", options: ClaudeAgent::Options.new(logger: my_logger))

# Or with Client
client = ClaudeAgent::Client.new(options: ClaudeAgent::Options.new(logger: my_logger))
```

### Log Output

When enabled, the SDK logs events across transport, protocol, parsing, MCP, and query layers:

```
[ClaudeAgent] [12:00:00.123] INFO  -- transport: Process spawned (pid=12345)
[ClaudeAgent] [12:00:00.456] DEBUG -- protocol: Sending control request: initialize (req_1_abc)
[ClaudeAgent] [12:00:01.789] INFO  -- protocol: Permission decision for Bash: allow
[ClaudeAgent] [12:00:02.100] INFO  -- query: Query complete (3.45s, cost=$0.012)
```

### Log Levels

| Level | What's Logged                                                                                                  |
|-------|----------------------------------------------------------------------------------------------------------------|
| ERROR | Control request failures, unknown message types                                                                |
| WARN  | Force kills, JSON parse errors during buffering, unknown MCP tools                                             |
| INFO  | Process spawn/close, protocol start/stop, permission decisions, tool calls, query start/completion with timing |
| DEBUG | Full commands, message types received, control request/response routing, reader thread lifecycle               |

## Environment Variables

The SDK sets these automatically:

- `CLAUDE_CODE_ENTRYPOINT=sdk-rb`
- `CLAUDE_AGENT_SDK_VERSION=<version>`

Enable debug logging via environment variable:

```bash
export CLAUDE_AGENT_DEBUG=1
```

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
ClaudeAgent.conversation() / ClaudeAgent::Conversation
           │
           │ Manages lifecycle, callbacks, turn history, tool activity
           │
           ▼
ClaudeAgent::Client
           │
           │ Event handlers, cumulative usage, permission queue
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
