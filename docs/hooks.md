# Hooks

Hooks let you intercept and respond to events during a Claude Code CLI session. When the CLI triggers an event (tool use, session start, notification, etc.), your Ruby callback is invoked with a typed input object and context. The callback returns a response hash that controls how the CLI proceeds.

## HookRegistry DSL

The recommended way to define hooks is through `HookRegistry`, a declarative builder that maps idiomatic Ruby method names to CLI hook events.

### Global hooks

Set hooks that apply to all queries and conversations:

```ruby
ClaudeAgent.hooks do |h|
  h.before_tool_use(/Bash/) do |input, ctx|
    puts "About to run Bash: #{input.tool_input}"
    { continue_: true }
  end

  h.on_session_start do |input, ctx|
    puts "Session started from #{input.source}"
    { continue_: true }
  end
end
```

Global hooks are stored in `ClaudeAgent.config.default_hooks` and are merged into every `Options` instance produced by `Configuration#to_options`.

### Per-conversation hooks

Pass a `HookRegistry` (or compiled hooks hash) to a specific conversation or query:

```ruby
hooks = ClaudeAgent::HookRegistry.new do |h|
  h.before_tool_use("Write") do |input, ctx|
    if input.tool_input[:file_path]&.end_with?(".env")
      { continue_: false }  # Block writes to .env files
    else
      { continue_: true }
    end
  end

  h.after_tool_use do |input, ctx|
    puts "#{input.tool_name} completed"
    { continue_: true }
  end
end

# With Conversation
ClaudeAgent.chat(hooks: hooks) do |c|
  c.say("Refactor the auth module")
end

# With ask
turn = ClaudeAgent.ask("Fix the tests", hooks: hooks)

# With explicit Options
opts = ClaudeAgent::Options.new(hooks: hooks, model: "opus")
```

When both global and per-conversation hooks are set, they are merged additively -- per-conversation hooks are appended to global hooks for the same event.

### Matchers

Each hook method accepts an optional first argument that filters which tool names trigger the callback. The matcher is passed as the first positional argument, before any keyword arguments.

| Matcher type    | Behavior                          | Example                                             |
|-----------------|-----------------------------------|-----------------------------------------------------|
| `nil` (omitted) | Catch-all, fires for every tool   | `h.before_tool_use { \|i, c\| ... }`                |
| `String`        | Treated as a regex pattern        | `h.before_tool_use("Bash") { \|i, c\| ... }`        |
| `Regexp`        | Normalized to its `source` string | `h.before_tool_use(/Bash\|Write/) { \|i, c\| ... }` |

A `Regexp` is converted to its `.source` string internally so it can be serialized over the control protocol. This means flags like `Regexp::IGNORECASE` are not preserved.

### Timeout

Pass a `timeout:` keyword argument to set a per-hook timeout in seconds:

```ruby
ClaudeAgent.hooks do |h|
  h.before_tool_use("Bash", timeout: 30) do |input, ctx|
    # Must return within 30 seconds
    { continue_: validate_command(input.tool_input) }
  end
end
```

### Chaining

Each DSL method returns `self`, so you can chain registrations:

```ruby
hooks = ClaudeAgent::HookRegistry.new
hooks
  .before_tool_use("Bash") { |i, _| { continue_: true } }
  .after_tool_use { |i, _| { continue_: true } }
  .on_stop { |i, _| { continue_: true } }
```

### Merging registries

Combine two registries additively with `merge`. The original registries are not modified.

```ruby
security_hooks = ClaudeAgent::HookRegistry.new do |h|
  h.before_tool_use(/Bash|Write/) { |i, _| audit(i); { continue_: true } }
end

logging_hooks = ClaudeAgent::HookRegistry.new do |h|
  h.on_session_start { |i, _| log_start(i); { continue_: true } }
  h.on_session_end { |i, _| log_end(i); { continue_: true } }
end

combined = security_hooks.merge(logging_hooks)
# combined has 1 PreToolUse matcher + 1 SessionStart matcher + 1 SessionEnd matcher

ClaudeAgent.configure do |c|
  c.default_hooks = combined
end
```

### Multiple matchers per event

You can register multiple callbacks for the same event. Each produces a separate `HookMatcher`:

```ruby
ClaudeAgent.hooks do |h|
  h.before_tool_use("Bash") { |i, _| log_bash(i); { continue_: true } }
  h.before_tool_use("Write") { |i, _| validate_write(i); { continue_: true } }
  h.before_tool_use { |i, _| audit_all(i); { continue_: true } }
end
```

## Event Mapping Table

All 23 hook events with their Ruby DSL method, CLI event name, and description:

| Ruby method              | CLI event            | Description                                     |
|--------------------------|----------------------|-------------------------------------------------|
| `before_tool_use`        | `PreToolUse`         | Before a tool is executed. Can block execution. |
| `after_tool_use`         | `PostToolUse`        | After a tool executes successfully.             |
| `after_tool_use_failure` | `PostToolUseFailure` | After a tool execution fails.                   |
| `on_notification`        | `Notification`       | When the CLI emits a notification.              |
| `on_user_prompt_submit`  | `UserPromptSubmit`   | When a user prompt is submitted.                |
| `on_session_start`       | `SessionStart`       | When a session begins.                          |
| `on_session_end`         | `SessionEnd`         | When a session ends.                            |
| `on_stop`                | `Stop`               | When the agent stops.                           |
| `on_stop_failure`        | `StopFailure`        | When the agent stops due to an API error.       |
| `on_subagent_start`      | `SubagentStart`      | When a subagent is spawned.                     |
| `on_subagent_stop`       | `SubagentStop`       | When a subagent stops.                          |
| `before_compact`         | `PreCompact`         | Before context compaction.                      |
| `after_compact`          | `PostCompact`        | After context compaction.                       |
| `on_permission_request`  | `PermissionRequest`  | When a permission prompt is shown.              |
| `on_setup`               | `Setup`              | During initialization or maintenance.           |
| `on_teammate_idle`       | `TeammateIdle`       | When a teammate agent becomes idle.             |
| `on_task_completed`      | `TaskCompleted`      | When an agent task completes.                   |
| `on_elicitation`         | `Elicitation`        | When an MCP server requests user input.         |
| `on_elicitation_result`  | `ElicitationResult`  | After an elicitation is resolved.               |
| `on_config_change`       | `ConfigChange`       | When a configuration file changes.              |
| `on_worktree_create`     | `WorktreeCreate`     | When a git worktree is created.                 |
| `on_worktree_remove`     | `WorktreeRemove`     | When a git worktree is removed.                 |
| `on_instructions_loaded` | `InstructionsLoaded` | When instructions files are loaded.             |

## Hook Input Types

Every hook callback receives `(input, context)`. The `input` argument is a subclass of `BaseHookInput`.

### Base fields

All input types inherit these fields from `BaseHookInput`:

| Field             | Type     | Description                               |
|-------------------|----------|-------------------------------------------|
| `hook_event_name` | `String` | The CLI event name (e.g., `"PreToolUse"`) |
| `session_id`      | `String` | Current session ID                        |
| `transcript_path` | `String` | Path to the session transcript file       |
| `cwd`             | `String` | Current working directory                 |
| `permission_mode` | `String` | Active permission mode                    |
| `agent_id`        | `String` | Agent identifier                          |
| `agent_type`      | `String` | Agent type                                |

### Event-specific fields

| CLI event            | Input class               | Key fields                                                                                                                              |
|----------------------|---------------------------|-----------------------------------------------------------------------------------------------------------------------------------------|
| `PreToolUse`         | `PreToolUseInput`         | `tool_name`, `tool_input`, `tool_use_id`                                                                                                |
| `PostToolUse`        | `PostToolUseInput`        | `tool_name`, `tool_input`, `tool_response`, `tool_use_id`                                                                               |
| `PostToolUseFailure` | `PostToolUseFailureInput` | `tool_name`, `tool_input`, `error`, `tool_use_id`, `is_interrupt`                                                                       |
| `Notification`       | `NotificationInput`       | `message`, `title`, `notification_type`                                                                                                 |
| `UserPromptSubmit`   | `UserPromptSubmitInput`   | `prompt`                                                                                                                                |
| `SessionStart`       | `SessionStartInput`       | `source`, `agent_type`, `model`                                                                                                         |
| `SessionEnd`         | `SessionEndInput`         | `reason`                                                                                                                                |
| `Stop`               | `StopInput`               | `stop_hook_active`, `last_assistant_message`                                                                                            |
| `StopFailure`        | `StopFailureInput`        | `error`, `error_details`, `last_assistant_message`                                                                                      |
| `SubagentStart`      | `SubagentStartInput`      | `agent_id`, `agent_type`                                                                                                                |
| `SubagentStop`       | `SubagentStopInput`       | `stop_hook_active`, `agent_id`, `agent_transcript_path`, `agent_type`, `last_assistant_message`                                         |
| `PreCompact`         | `PreCompactInput`         | `trigger`, `custom_instructions`                                                                                                        |
| `PostCompact`        | `PostCompactInput`        | `trigger`, `compact_summary`                                                                                                            |
| `PermissionRequest`  | `PermissionRequestInput`  | `tool_name`, `tool_input`, `permission_suggestions`                                                                                     |
| `Setup`              | `SetupInput`              | `trigger` (also has `init?` and `maintenance?` predicates)                                                                              |
| `TeammateIdle`       | `TeammateIdleInput`       | `teammate_name`, `team_name`                                                                                                            |
| `TaskCompleted`      | `TaskCompletedInput`      | `task_id`, `task_subject`, `task_description`, `teammate_name`, `team_name`                                                             |
| `Elicitation`        | `ElicitationInput`        | `mcp_server_name`, `message`, `mode`, `url`, `elicitation_id`, `requested_schema`                                                       |
| `ElicitationResult`  | `ElicitationResultInput`  | `mcp_server_name`, `action`, `elicitation_id`, `mode`, `content`                                                                        |
| `ConfigChange`       | `ConfigChangeInput`       | `source`, `file_path` (constant: `SOURCES`)                                                                                             |
| `WorktreeCreate`     | `WorktreeCreateInput`     | `name`                                                                                                                                  |
| `WorktreeRemove`     | `WorktreeRemoveInput`     | `worktree_path`                                                                                                                         |
| `InstructionsLoaded` | `InstructionsLoadedInput` | `file_path`, `memory_type`, `load_reason`, `globs`, `trigger_file_path`, `parent_file_path` (constants: `MEMORY_TYPES`, `LOAD_REASONS`) |

### Context

The `context` argument is a `Hash` with:

| Field         | Type     | Description                                      |
|---------------|----------|--------------------------------------------------|
| `tool_use_id` | `String` | The tool use ID (present for tool-related hooks) |

## Hook Response Format

Callbacks must return a `Hash`. The SDK normalizes Ruby-style keys to the camelCase format expected by the CLI.

### Key mapping

| Ruby key               | CLI key              | Type      | Description                                                                                           |
|------------------------|----------------------|-----------|-------------------------------------------------------------------------------------------------------|
| `continue_`            | `continue`           | `Boolean` | Whether to continue execution. Note the trailing underscore -- `continue` is a reserved word in Ruby. |
| `decision`             | `decision`           | `String`  | Permission decision: `"allow"` or `"deny"`                                                            |
| `reason`               | `reason`             | `String`  | Explanation for the decision                                                                          |
| `suppress_output`      | `suppressOutput`     | `Boolean` | Whether to suppress tool output                                                                       |
| `stop_reason`          | `stopReason`         | `String`  | Reason for stopping                                                                                   |
| `system_message`       | `systemMessage`      | `String`  | System message to inject                                                                              |
| `async_`               | `async`              | `Boolean` | Whether to handle asynchronously                                                                      |
| `async_timeout`        | `asyncTimeout`       | `Integer` | Timeout for async operations                                                                          |
| `hook_specific_output` | `hookSpecificOutput` | `Hash`    | Event-specific output (keys are auto-camelCased)                                                      |

The plain `continue` key also works (it is mapped identically), but `continue_` is preferred for consistency with Ruby conventions.

### Common response patterns

**Allow execution to proceed:**

```ruby
{ continue_: true }
```

**Block execution:**

```ruby
{ continue_: false }
```

**Block with a reason:**

```ruby
{ continue_: false, reason: "Writes to .env files are not allowed" }
```

**Inject a system message:**

```ruby
{ continue_: true, system_message: "Remember to add tests for any new code." }
```

**Suppress tool output:**

```ruby
{ continue_: true, suppress_output: true }
```

## Raw Options Approach

As an alternative to the DSL, you can construct the hooks hash directly using `HookMatcher` instances. This is the underlying format that `HookRegistry#to_hooks_hash` produces.

```ruby
hooks = {
  "PreToolUse" => [
    ClaudeAgent::HookMatcher.new(
      matcher: "Bash|Write",
      callbacks: [
        ->(input, ctx) { { continue_: true } }
      ],
      timeout: 30
    )
  ],
  "SessionStart" => [
    ClaudeAgent::HookMatcher.new(
      matcher: nil,
      callbacks: [
        ->(input, ctx) { puts "Session started"; { continue_: true } }
      ]
    )
  ]
}

opts = ClaudeAgent::Options.new(hooks: hooks)
turn = ClaudeAgent.ask("Hello", options: opts)
```

Each key is a CLI event name string (e.g., `"PreToolUse"`). Each value is an array of `HookMatcher` instances. A `HookMatcher` is a `Data.define` with three fields:

| Field       | Type             | Description                                                  |
|-------------|------------------|--------------------------------------------------------------|
| `matcher`   | `String`, `nil`  | Regex pattern string to match tool names. `nil` matches all. |
| `callbacks` | `Array<Proc>`    | Array of callback procs. Each receives `(input, context)`.   |
| `timeout`   | `Integer`, `nil` | Optional timeout in seconds.                                 |

`HookMatcher#matches?(tool_name)` tests whether a tool name matches the pattern. A pipe-separated string like `"Bash|Write"` matches if the tool name equals any segment; other strings are treated as regex patterns.

## Hook Lifecycle Messages

When hooks execute, the CLI emits lifecycle messages that appear in your message stream:

| Message type  | Class                 | Description                                              |
|---------------|-----------------------|----------------------------------------------------------|
| Hook started  | `HookStartedMessage`  | Emitted when hook execution begins                       |
| Hook progress | `HookProgressMessage` | Reports progress during execution (stdout/stderr/output) |
| Hook response | `HookResponseMessage` | Final result with exit code and outcome                  |

`HookResponseMessage` provides convenience predicates: `success?`, `error?`, `cancelled?`.

```ruby
ClaudeAgent.ask("Run tests") do |msg|
  case msg
  when ClaudeAgent::HookStartedMessage
    puts "Hook #{msg.hook_name} started (event: #{msg.hook_event})"
  when ClaudeAgent::HookResponseMessage
    if msg.error?
      warn "Hook #{msg.hook_name} failed: #{msg.stderr}"
    end
  end
end
```

## Full Example

```ruby
# Global audit hooks
ClaudeAgent.hooks do |h|
  h.before_tool_use(/Bash/) do |input, _ctx|
    command = input.tool_input[:command] || input.tool_input["command"]
    if command&.include?("rm -rf")
      { continue_: false, reason: "Destructive commands are blocked" }
    else
      { continue_: true }
    end
  end

  h.before_tool_use("Write") do |input, _ctx|
    path = input.tool_input[:file_path] || input.tool_input["file_path"]
    if path&.match?(/\.(env|pem|key)$/)
      { continue_: false, reason: "Cannot write to sensitive files" }
    else
      { continue_: true }
    end
  end

  h.after_tool_use do |input, _ctx|
    log_tool_use(input.tool_name, input.tool_input)
    { continue_: true }
  end

  h.on_session_start do |input, _ctx|
    puts "Session started (source=#{input.source}, model=#{input.model})"
    { continue_: true }
  end

  h.on_stop do |input, _ctx|
    puts "Agent stopped"
    { continue_: true }
  end
end

# Per-conversation hooks layered on top
review_hooks = ClaudeAgent::HookRegistry.new do |h|
  h.before_tool_use("Write") do |input, _ctx|
    { continue_: true, system_message: "Always add inline comments explaining changes." }
  end
end

turn = ClaudeAgent.ask("Refactor the auth module", hooks: review_hooks)
puts turn.text
```
