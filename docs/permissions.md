# Permissions

The ClaudeAgent Ruby SDK provides layered control over which tools Claude can
use during a conversation. Start with the declarative `PermissionPolicy` DSL
for most use cases. Drop down to the raw `can_use_tool` lambda when you need
full control.

## Permission Modes

Set a CLI-level permission mode via `permission_mode`. This controls how the
Claude Code CLI handles tool-permission prompts before your SDK callback is
ever invoked.

| Mode                  | Effect                                         |
|-----------------------|------------------------------------------------|
| `"default"`           | CLI prompts for each tool (normal behavior)    |
| `"acceptEdits"`       | Auto-accept file-edit tools, prompt for others |
| `"plan"`              | Plan mode -- no tool execution                 |
| `"dontAsk"`           | Auto-accept all tools, never prompt            |
| `"bypassPermissions"` | Skip all permission checks (dangerous)         |

```ruby
options = ClaudeAgent::Options.new(
  permission_mode: "acceptEdits"
)
```

`"bypassPermissions"` requires an explicit opt-in:

```ruby
options = ClaudeAgent::Options.new(
  permission_mode: "bypassPermissions",
  allow_dangerously_skip_permissions: true
)
```

Valid modes are defined in `ClaudeAgent::PERMISSION_MODES`.

---

## PermissionPolicy DSL

`PermissionPolicy` is a declarative builder that compiles allow/deny rules into
a `can_use_tool` lambda. Rules are evaluated in declaration order; first match
wins.

### Basic usage

```ruby
policy = ClaudeAgent::PermissionPolicy.new do |p|
  p.allow "Read", "Grep", "Glob"
  p.deny "Bash", message: "Shell access not allowed"
  p.deny_all
end
```

### Rule methods

#### `allow(*tool_names)`

Allow one or more tools by exact name.

```ruby
p.allow "Read"
p.allow "Write", "Edit"
```

#### `deny(*tool_names, message:, interrupt:)`

Deny one or more tools by exact name. Optional `message` is returned to
Claude as the denial reason. Set `interrupt: true` to stop the conversation
instead of letting Claude retry with a different approach.

```ruby
p.deny "Bash", message: "Bash is disabled"
p.deny "Write", "Edit", message: "Read-only mode", interrupt: true
```

#### `allow_matching(pattern)`

Allow tools whose name matches a `Regexp` or string pattern.

```ruby
p.allow_matching(/^mcp__/)               # Regexp
p.allow_matching("^mcp__myserver__")     # String (compiled to Regexp)
```

#### `deny_matching(pattern, message:, interrupt:)`

Deny tools whose name matches a pattern.

```ruby
p.deny_matching(/^Write|^Edit/, message: "Read-only mode")
```

#### `allow_all`

Set the fallback for unmatched tools to allow.

```ruby
p.deny "Bash"
p.allow_all   # everything except Bash is allowed
```

#### `deny_all(message:)`

Set the fallback for unmatched tools to deny.

```ruby
p.allow "Read", "Grep"
p.deny_all   # everything except Read and Grep is denied
```

Default message is `"Denied by policy"`.

#### `ask(&handler)`

Set a custom fallback handler for tools that don't match any rule. The block
receives `(tool_name, tool_input, context)` and must return a
`PermissionResultAllow` or `PermissionResultDeny`.

```ruby
p.allow "Read"
p.ask do |name, input, context|
  if name.start_with?("mcp__")
    ClaudeAgent::PermissionResultAllow.new
  else
    ClaudeAgent::PermissionResultDeny.new(message: "Unknown tool: #{name}")
  end
end
```

### First match wins

Rules are evaluated top-to-bottom. The first matching rule determines the
outcome. If no rule matches and no fallback is set, the default is allow.

```ruby
policy = ClaudeAgent::PermissionPolicy.new do |p|
  p.allow "Bash"     # this wins for "Bash"
  p.deny "Bash"      # never reached
end
```

### Compiling to a lambda

`to_can_use_tool` compiles the policy into a lambda compatible with
`Options#can_use_tool`:

```ruby
handler = policy.to_can_use_tool
result = handler.call("Read", { file_path: "/tmp/foo" }, context)
result.behavior  # => "allow"
```

All rule methods return `self`, so you can chain:

```ruby
policy = ClaudeAgent::PermissionPolicy.new
policy.allow("Read").deny("Bash").deny_all
```

### Global permissions

Set a policy that applies to all `ClaudeAgent.ask` and `ClaudeAgent.chat`
calls:

```ruby
ClaudeAgent.permissions do |p|
  p.allow "Read", "Grep", "Glob"
  p.deny "Bash"
  p.deny_all
end

# This call inherits the global policy
turn = ClaudeAgent.ask("Summarize the codebase")
```

Per-request `can_use_tool` overrides the global policy.

### Per-conversation permissions

Pass a `PermissionPolicy` as `on_permission` in `Conversation`:

```ruby
policy = ClaudeAgent::PermissionPolicy.new do |p|
  p.allow "Read"
  p.deny_all
end

ClaudeAgent::Conversation.open(on_permission: policy) do |c|
  c.say("Read the README")
end
```

---

## Symbol Permission Modes in Conversation

`Conversation` accepts Ruby symbols for `on_permission` as a shorthand for
CLI permission modes:

| Symbol                | Maps to CLI mode         |
|-----------------------|--------------------------|
| `:default`            | `"default"`              |
| `:accept_edits`       | `"acceptEdits"`          |
| `:plan`               | `"plan"`                 |
| `:dont_ask`           | `"dontAsk"`              |
| `:bypass_permissions` | `"bypassPermissions"`    |
| `:queue`              | Enables permission queue |

```ruby
ClaudeAgent::Conversation.open(on_permission: :accept_edits) do |c|
  c.say("Fix the typo in README.md")
end

ClaudeAgent::Conversation.open(on_permission: :dont_ask) do |c|
  c.say("Refactor the auth module")
end
```

When `on_permission` is `nil` (the default), the Conversation enables the
permission queue automatically so permission requests can be resolved
programmatically.

---

## can_use_tool Callback (Advanced)

For full control, pass a lambda directly as `can_use_tool`. It receives three
arguments and must return a `PermissionResultAllow` or `PermissionResultDeny`.

```ruby
options = ClaudeAgent::Options.new(
  can_use_tool: ->(tool_name, tool_input, context) {
    case tool_name
    when "Read", "Grep", "Glob"
      ClaudeAgent::PermissionResultAllow.new
    when "Bash"
      if tool_input[:command]&.start_with?("ls")
        ClaudeAgent::PermissionResultAllow.new
      else
        ClaudeAgent::PermissionResultDeny.new(
          message: "Only ls commands allowed",
          interrupt: false
        )
      end
    else
      ClaudeAgent::PermissionResultDeny.new(message: "Not allowed")
    end
  }
)
```

### ToolPermissionContext

The third argument is a `ToolPermissionContext` with these fields:

| Field                    | Type                | Description                                              |
|--------------------------|---------------------|----------------------------------------------------------|
| `permission_suggestions` | `Array<Hash>, nil`  | Suggested permission updates from the CLI                |
| `blocked_path`           | `String, nil`       | Path that triggered the permission check                 |
| `decision_reason`        | `String, nil`       | Why the CLI is asking for permission                     |
| `tool_use_id`            | `String, nil`       | Unique ID for this tool invocation                       |
| `agent_id`               | `String, nil`       | ID of the agent requesting the tool                      |
| `description`            | `String, nil`       | Human-readable description of the tool action            |
| `signal`                 | `AbortSignal, nil`  | Abort signal for cancellation                            |
| `request`                | `PermissionRequest` | The underlying request object (for hybrid/deferred mode) |

```ruby
can_use_tool: ->(name, input, context) {
  puts "Tool: #{name}"
  puts "Reason: #{context.decision_reason}"
  puts "Blocked path: #{context.blocked_path}"

  ClaudeAgent::PermissionResultAllow.new
}
```

### Auto-configuration

When `can_use_tool` or `permission_queue` is set, the SDK automatically sets
`permission_prompt_tool_name` to `"stdio"` so the CLI routes permission
prompts through the control protocol instead of interactive terminal prompts.

---

## Permission Results

Both the `PermissionPolicy` DSL and the raw `can_use_tool` callback return
typed result objects.

### PermissionResultAllow

```ruby
# Simple allow
ClaudeAgent::PermissionResultAllow.new

# Allow with modified input (the tool sees this instead of the original)
ClaudeAgent::PermissionResultAllow.new(
  updated_input: { command: "ls -la /tmp" }
)

# Allow with permission updates (persist new rules)
ClaudeAgent::PermissionResultAllow.new(
  updated_permissions: [
    ClaudeAgent::PermissionUpdate.new(
      type: "addRules",
      rules: [{ tool_name: "Read", rule_content: "/**" }],
      behavior: "allow"
    )
  ]
)
```

Fields:

| Field                 | Type                           | Default | Description                                                                 |
|-----------------------|--------------------------------|---------|-----------------------------------------------------------------------------|
| `updated_input`       | `Hash, nil`                    | `nil`   | Modified tool input                                                         |
| `updated_permissions` | `Array<PermissionUpdate>, nil` | `nil`   | Permission rule updates to apply                                            |
| `tool_use_id`         | `String, nil`                  | `nil`   | Tool invocation ID (set automatically when resolving via PermissionRequest) |

### PermissionResultDeny

```ruby
# Simple deny
ClaudeAgent::PermissionResultDeny.new(message: "Not allowed")

# Deny and interrupt the conversation
ClaudeAgent::PermissionResultDeny.new(
  message: "Dangerous operation blocked",
  interrupt: true
)
```

Fields:

| Field         | Type          | Default | Description                                                                 |
|---------------|---------------|---------|-----------------------------------------------------------------------------|
| `message`     | `String`      | `""`    | Denial reason (shown to Claude)                                             |
| `interrupt`   | `Boolean`     | `false` | If true, stop the conversation entirely                                     |
| `tool_use_id` | `String, nil` | `nil`   | Tool invocation ID (set automatically when resolving via PermissionRequest) |

Both types respond to `behavior` (`"allow"` or `"deny"`) and `to_h` for
serialization.

---

## Permission Queue

Queue-based permissions let you handle permission requests asynchronously,
which is useful for UI-driven applications where a human reviews each
request.

### Enabling the queue

The queue is enabled automatically in `Conversation` when no `on_permission`
or `can_use_tool` is provided:

```ruby
# Queue is enabled by default
conversation = ClaudeAgent::Conversation.new
```

You can also enable it explicitly:

```ruby
# Via symbol
conversation = ClaudeAgent::Conversation.new(on_permission: :queue)

# Via Options
options = ClaudeAgent::Options.new(permission_queue: true)
client = ClaudeAgent::Client.new(options: options)
```

### Consuming the queue

Poll for pending requests from a UI thread or event loop. Each request is a
`PermissionRequest` that you resolve by calling `allow!` or `deny!`.

```ruby
conversation = ClaudeAgent::Conversation.new

# Send a message in a background thread
thread = Thread.new { conversation.say("Refactor the auth module") }

# Poll for permission requests from the main thread
loop do
  if request = conversation.pending_permission
    puts "Tool: #{request.tool_name}"
    puts "Input: #{request.input}"
    puts "Label: #{request.display_label}"

    # Resolve the request
    request.allow!
    # or: request.deny!(message: "Not now")
  end

  break unless thread.alive?
  sleep 0.05
end

thread.join
```

### PermissionRequest API

| Method / Field  | Description                                                        |
|-----------------|--------------------------------------------------------------------|
| `tool_name`     | Name of the tool requesting permission                             |
| `input`         | Tool input (Hash with symbol keys)                                 |
| `context`       | `ToolPermissionContext` with metadata                              |
| `request_id`    | Unique ID for this request                                         |
| `created_at`    | `Time` when the request was created                                |
| `allow!`        | Allow the tool (optional `updated_input:`, `updated_permissions:`) |
| `deny!`         | Deny the tool (optional `message:`, `interrupt:`)                  |
| `defer!`        | Mark as deferred (for hybrid mode)                                 |
| `pending?`      | `true` if not yet resolved                                         |
| `resolved?`     | `true` if resolved                                                 |
| `deferred?`     | `true` if deferred via `defer!`                                    |
| `result`        | The resolution result, or `nil`                                    |
| `wait`          | Block until resolved (used internally)                             |
| `display_label` | Human-readable label (e.g., `"Bash: rm -rf /tmp"`)                 |
| `summary(max:)` | Detailed summary, truncated to `max` chars                         |

### PermissionQueue API

| Method            | Description                                      |
|-------------------|--------------------------------------------------|
| `poll`            | Non-blocking; returns next request or `nil`      |
| `pop(timeout:)`   | Blocking; waits for a request (optional timeout) |
| `empty?`          | Whether the queue has pending requests           |
| `size`            | Number of pending requests                       |
| `drain!(reason:)` | Deny all pending requests and clear the queue    |

On `Client`, use the convenience methods:

```ruby
client.pending_permission      # => PermissionRequest or nil
client.pending_permissions?    # => true/false
```

On `Conversation`, the same methods are available:

```ruby
conversation.pending_permission
conversation.pending_permissions?
```

### Thread safety

`PermissionRequest` uses a `Mutex` and `ConditionVariable` internally.
Multiple threads can safely race to resolve the same request -- the first
wins, and subsequent calls raise `ClaudeAgent::Error`.

---

## Hybrid Mode

Combine a synchronous `can_use_tool` callback with the deferred queue. In
the callback, return a result for tools you can decide on immediately, and
call `context.request.defer!` for tools that need human review.

```ruby
options = ClaudeAgent::Options.new(
  permission_queue: true,
  can_use_tool: ->(name, input, context) {
    case name
    when "Read", "Grep", "Glob"
      # Auto-allow read-only tools
      ClaudeAgent::PermissionResultAllow.new
    when "Bash"
      if input[:command]&.start_with?("ls", "cat", "echo")
        ClaudeAgent::PermissionResultAllow.new
      else
        # Defer dangerous commands to the UI queue
        context.request.defer!
      end
    else
      # Defer everything else
      context.request.defer!
    end
  }
)

client = ClaudeAgent::Client.new(options: options)
client.connect

# Background: send message and receive response
thread = Thread.new do
  client.send_and_receive("Deploy the application")
end

# Main thread: handle deferred permission requests
loop do
  if request = client.pending_permission
    puts "Approve #{request.display_label}? (y/n)"
    answer = gets.chomp
    if answer == "y"
      request.allow!
    else
      request.deny!(message: "User declined")
    end
  end

  break unless thread.alive?
  sleep 0.05
end

thread.join
client.disconnect
```

When `defer!` is called, the protocol enqueues the request and blocks the
reader thread until the request is resolved via `allow!` or `deny!` from
another thread.

---

## Permission Updates

Permission updates let you modify the CLI's permission rules at runtime as
part of an allow response.

### PermissionUpdate

```ruby
ClaudeAgent::PermissionUpdate.new(
  type: "addRules",
  rules: [
    { tool_name: "Read", rule_content: "/home/user/project/**" }
  ],
  behavior: "allow",
  destination: "session"
)
```

| Field         | Type                 | Description                      |
|---------------|----------------------|----------------------------------|
| `type`        | `String`             | Update operation type (required) |
| `rules`       | `Array<Hash>, nil`   | Rules to add/replace/remove      |
| `behavior`    | `String, nil`        | `"allow"` or `"deny"`            |
| `mode`        | `String, nil`        | Permission mode (for `setMode`)  |
| `directories` | `Array<String>, nil` | Directories to add/remove        |
| `destination` | `String, nil`        | Where to persist the update      |

#### Update types

| Type                  | Purpose                      |
|-----------------------|------------------------------|
| `"addRules"`          | Add new permission rules     |
| `"replaceRules"`      | Replace all rules for a tool |
| `"removeRules"`       | Remove specific rules        |
| `"setMode"`           | Change the permission mode   |
| `"addDirectories"`    | Add allowed directories      |
| `"removeDirectories"` | Remove allowed directories   |

#### Destinations

| Destination         | Scope                                |
|---------------------|--------------------------------------|
| `"userSettings"`    | User-wide settings                   |
| `"projectSettings"` | Project `.claude/` settings          |
| `"localSettings"`   | Local `.claude/*.local.*` settings   |
| `"session"`         | Current session only                 |
| `"cliArg"`          | CLI argument scope                   |

### PermissionRuleValue

Individual rules use `PermissionRuleValue`:

```ruby
rule = ClaudeAgent::PermissionRuleValue.new(
  tool_name: "Write",
  rule_content: "/tmp/**"
)

rule.to_h  # => { toolName: "Write", ruleContent: "/tmp/**" }
```

### Applying updates via PermissionResultAllow

```ruby
can_use_tool: ->(name, input, context) {
  ClaudeAgent::PermissionResultAllow.new(
    updated_permissions: [
      ClaudeAgent::PermissionUpdate.new(
        type: "addRules",
        rules: [{ tool_name: name, rule_content: "/**" }],
        behavior: "allow",
        destination: "session"
      )
    ]
  )
}
```

### Applying updates via PermissionRequest

```ruby
request.allow!(
  updated_permissions: [
    ClaudeAgent::PermissionUpdate.new(
      type: "setMode",
      mode: "acceptEdits",
      destination: "session"
    )
  ]
)
```
