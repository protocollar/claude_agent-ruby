# Error Handling

All errors inherit from `ClaudeAgent::Error`, which inherits from `StandardError`. You can rescue the base class to catch any SDK error, or rescue specific subclasses for targeted handling.

## Error Hierarchy

```
StandardError
  ClaudeAgent::Error
    CLINotFoundError         — Claude Code CLI binary not found
    CLIVersionError          — CLI version below MINIMUM_VERSION ("2.0.0")
    CLIConnectionError       — connection to CLI process failed
    ProcessError             — CLI process exited with error
    JSONDecodeError          — JSON parsing failed
    MessageParseError        — message structure could not be parsed
    TimeoutError             — control protocol request timed out
    ConfigurationError       — invalid option provided
    NotFoundError            — resource not found (e.g., Session.retrieve)
    AbortError               — operation aborted/cancelled
```

## Error Details

| Error                | Attributes                      | Raised When                                                                     |
|----------------------|---------------------------------|---------------------------------------------------------------------------------|
| `CLINotFoundError`   | --                              | CLI binary not at expected path                                                 |
| `CLIVersionError`    | --                              | `claude -v` returns < 2.0.0                                                     |
| `CLIConnectionError` | --                              | Pipe broken, stdin/stdout closed, already/not connected                         |
| `ProcessError`       | `exit_code`, `stderr`           | CLI process exits non-zero                                                      |
| `JSONDecodeError`    | `raw_content`                   | Malformed JSON from CLI, buffer overflow                                        |
| `MessageParseError`  | `raw_message`                   | Message structure unrecognizable                                                |
| `TimeoutError`       | `request_id`, `timeout_seconds` | Control protocol request exceeds deadline                                       |
| `ConfigurationError` | --                              | Invalid `Options` values (bad permission_mode, non-callable can_use_tool, etc.) |
| `NotFoundError`      | --                              | `Session.retrieve` or `Session.info` for nonexistent session                    |
| `AbortError`         | `partial_turn`                  | `AbortController#abort` called, or session closed mid-turn                      |

## Handling Pattern

```ruby
require "claude_agent"

begin
  turn = ClaudeAgent.ask("Fix the failing tests")
  puts turn.text

rescue ClaudeAgent::CLINotFoundError
  # Install or update PATH
  abort "Claude Code CLI is not installed."

rescue ClaudeAgent::CLIVersionError
  # Upgrade CLI
  abort "Claude Code CLI is too old. Run: claude update"

rescue ClaudeAgent::CLIConnectionError => e
  # Pipe broken, process died, etc.
  $stderr.puts "Connection lost: #{e.message}"

rescue ClaudeAgent::ProcessError => e
  # CLI exited with an error code
  $stderr.puts "CLI failed (exit #{e.exit_code}): #{e.stderr}"

rescue ClaudeAgent::JSONDecodeError => e
  # Corrupted output from CLI
  $stderr.puts "Bad JSON: #{e.raw_content&.slice(0, 200)}"

rescue ClaudeAgent::MessageParseError => e
  # Unexpected message structure
  $stderr.puts "Unparseable message: #{e.raw_message.inspect}"

rescue ClaudeAgent::TimeoutError => e
  # Control protocol deadline exceeded
  $stderr.puts "Timed out after #{e.timeout_seconds}s (request: #{e.request_id})"

rescue ClaudeAgent::ConfigurationError => e
  # Bad options (caught at Options construction time)
  abort "Invalid config: #{e.message}"

rescue ClaudeAgent::NotFoundError => e
  # Session.retrieve for a session that does not exist
  $stderr.puts "Not found: #{e.message}"

rescue ClaudeAgent::AbortError => e
  # Operation cancelled -- see next section for partial results
  $stderr.puts "Aborted: #{e.message}"

rescue ClaudeAgent::Error => e
  # Catch-all for any SDK error not handled above
  $stderr.puts "ClaudeAgent error: #{e.message}"
end
```

## AbortError and Partial Results

When a turn is aborted mid-flight (via `AbortController` or session close), the `AbortError` carries a `partial_turn` -- a `TurnResult` containing whatever was accumulated before cancellation.

```ruby
controller = ClaudeAgent::AbortController.new

# Abort after 5 seconds
Thread.new { sleep 5; controller.abort("Taking too long") }

begin
  conversation = ClaudeAgent::Conversation.new(
    options: ClaudeAgent::Options.new(abort_controller: controller)
  )
  turn = conversation.say("Refactor the entire codebase")
rescue ClaudeAgent::AbortError => e
  turn = e.partial_turn

  if turn
    # Text accumulated from assistant messages (or streamed fragments)
    puts "Partial text: #{turn.text}" unless turn.text.empty?

    # Tools that were invoked before the abort
    turn.tool_uses.each do |tool|
      puts "Tool called: #{tool.name}"
    end

    # All raw messages received so far
    puts "Messages received: #{turn.messages.size}"
  else
    puts "Aborted before any messages were received."
  end
end
```

`partial_turn` is `nil` if the abort happened before any messages arrived. Always check before accessing its fields.
