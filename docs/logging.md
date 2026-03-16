# Logging

The SDK ships with a `NullLogger` by default -- zero overhead, no output. Enable logging when you need visibility into transport lifecycle, message routing, and protocol decisions.

## Quick Debug

Turn on debug logging to stderr with one call:

```ruby
ClaudeAgent.debug!
```

Log to a file instead:

```ruby
ClaudeAgent.debug!(output: File.open("claude_agent.log", "a"))
```

Or set the environment variable before your process starts:

```bash
CLAUDE_AGENT_DEBUG=1 ruby my_script.rb
```

## Custom Logger

Assign any `Logger`-compatible instance at the module level. All queries and conversations will use it unless overridden per-query.

```ruby
ClaudeAgent.logger = Logger.new($stderr, level: :info)
```

To use the SDK's compact formatter with a custom logger:

```ruby
ClaudeAgent.logger = Logger.new($stderr, level: :debug).tap do |l|
  l.formatter = ClaudeAgent::LOG_FORMATTER
end
```

## Per-Query Logger

Pass a `logger` to `Options` to override the module-level logger for a single query or conversation. This is useful when running multiple queries concurrently with separate log destinations.

```ruby
query_logger = Logger.new("query_debug.log", level: :debug)
query_logger.formatter = ClaudeAgent::LOG_FORMATTER

turn = ClaudeAgent.ask("What is 2+2?",
  logger: query_logger
)
```

The resolution order is: `Options#logger` > `ClaudeAgent.logger` > `NullLogger`. This is handled by `Options#effective_logger`.

## Log Output Format

All log lines follow this format:

```
[ClaudeAgent] [HH:MM:SS.mmm] LEVEL -- tag: message
```

Example output:

```
[ClaudeAgent] [14:32:01.456] INFO  -- transport: Process spawned (pid=12345)
[ClaudeAgent] [14:32:01.457] DEBUG -- transport: Command: claude --print --output-format json
[ClaudeAgent] [14:32:01.789] INFO  -- protocol: Starting control protocol (streaming=true)
[ClaudeAgent] [14:32:02.012] INFO  -- protocol: Initialize complete
[ClaudeAgent] [14:32:02.345] DEBUG -- parser: Parsing message: assistant
[ClaudeAgent] [14:32:03.678] INFO  -- query: Query complete (1.89s, cost=$0.003)
```

The `tag` identifies the component: `transport`, `protocol`, `parser`, `query`, `client`, `conversation`, `mcp.<name>`.

## Log Levels

| Level     | What Gets Logged                                                                                                                          |
|-----------|-------------------------------------------------------------------------------------------------------------------------------------------|
| **ERROR** | Control protocol request failures, unknown error conditions                                                                               |
| **WARN**  | Force kills, message parse errors, unknown message types, unknown MCP tools                                                               |
| **INFO**  | Process spawn/close, protocol start/stop, initialize completion, query timing and cost, tool calls, permission decisions, auto-connect    |
| **DEBUG** | Full CLI commands, working directory, raw bytes written, message routing, control request/response details, protocol reader thread events |

## NullLogger

The default logger. All methods (`debug`, `info`, `warn`, `error`, `fatal`) return `true` immediately without performing any I/O. Level predicates (`debug?`, `info?`, etc.) return `false`, so guarded log blocks are never evaluated:

```ruby
logger = ClaudeAgent::NullLogger.new
logger.info?                                    # => false
logger.info("transport") { "This is discarded" } # => true (no-op)
```

This means logging calls in hot paths have no measurable cost when logging is not enabled.
