# ClaudeAgent Ruby SDK

Ruby SDK for building autonomous AI agents that interact with Claude Code CLI. See [README.md](README.md) for a quick start, and the [docs/](docs/) folder for full guides:

| Guide                                      | What's in it                                         |
|--------------------------------------------|------------------------------------------------------|
| [Getting Started](docs/getting-started.md) | Install, first queries, multi-turn basics            |
| [Configuration](docs/configuration.md)     | Global config, Options, sandbox, agents              |
| [Conversations](docs/conversations.md)     | Multi-turn API, TurnResult, callbacks, tool tracking |
| [Queries](docs/queries.md)                 | One-shot: ask, query_turn, query                     |
| [Permissions](docs/permissions.md)         | PermissionPolicy DSL, can_use_tool, queue            |
| [Hooks](docs/hooks.md)                     | HookRegistry DSL, hook events, input types           |
| [MCP Tools](docs/mcp.md)                   | In-process tools, servers, schemas                   |
| [Events](docs/events.md)                   | EventHandler, typed callbacks                        |
| [Messages](docs/messages.md)               | 22 message types, 8 content blocks, pattern matching |
| [Sessions](docs/sessions.md)               | Session discovery, mutations, forking                |
| [Client](docs/client.md)                   | Low-level bidirectional API                          |
| [Errors](docs/errors.md)                   | Error hierarchy                                      |
| [Logging](docs/logging.md)                 | Debug logging, log levels                            |
| [Architecture](docs/architecture.md)       | Internal design, data flow                           |

## Stack

- **Ruby** 3.2+ (uses `Data.define` for immutable types)
- **Minitest** for testing
- **RuboCop** with `rubocop-rails-omakase` for linting
- **RBS** for type signatures (in `sig/`)
- **No external API clients** - communicates with Claude Code CLI via JSON Lines protocol

## Workflow

```bash
bin/setup                          # Install dependencies
bundle exec rake                   # Run unit tests + rbs + rubocop (default)
bundle exec rake test              # Unit tests only
bundle exec rake test_integration  # Integration tests (requires CLI v2.0.0+)
bundle exec rake test_smoke        # Smoke tests against local LLM (e.g. Ollama)
bundle exec rake test_all          # All tests (requires CLI v2.0.0+)
bundle exec rake rbs               # Validate RBS signatures
bundle exec rake rbs:parse         # RBS syntax check only (faster)
bundle exec rake rbs:prototype     # Generate RBS from lib/ (for new code)
bundle exec rubocop                # Lint only
bin/console                        # IRB with gem loaded

# Binstubs
bin/test                           # Unit tests only
bin/test-integration               # Integration tests
bin/test-all                       # All tests
bin/test-smoke                     # Smoke tests (Ollama)
bin/rbs-validate                   # Validate RBS signatures
bin/release VERSION                # Release gem (e.g., bin/release 1.2.0)
```

## Conventions

- **Immutable data types**: All messages and content blocks use `Data.define`, frozen at construction
- **Frozen string literals**: Every file starts with `# frozen_string_literal: true`
- **Message module**: All message/block types include `ClaudeAgent::Message` (text_content, pattern matching)
- **Stripe-style config**: `ClaudeAgent.model = "opus"`, `ClaudeAgent.configure { |c| ... }`, `Configuration#to_options`
- **Convenience entry points**: `ClaudeAgent.ask(prompt)` (one-shot), `ClaudeAgent.chat { |c| ... }` (multi-turn)
- **DSL builders**: `PermissionPolicy` and `HookRegistry` compile to lambdas/hashes consumed by Options
- **Error hierarchy**: All errors inherit from `ClaudeAgent::Error` with context (exit code, stderr, etc.)
- **Protocol flow**: Configuration → Options → Transport → ControlProtocol → MessageParser → typed messages

## Testing Notes

- Unit tests in `test/claude_agent/` - run without Claude CLI
- Integration tests in `test/integration/` - require Claude Code CLI v2.0.0+
- Integration tests are skipped by default; set `INTEGRATION=true` to run them
- Skip CLI version check with `CLAUDE_AGENT_SDK_SKIP_VERSION_CHECK=true`

## Releasing

Uses [Semantic Versioning](https://semver.org/) and [Keep a Changelog](https://keepachangelog.com/) format.

```bash
# 1. Update CHANGELOG.md with version entry
# 2. Commit the changelog
git commit -am "docs: update changelog for X.Y.Z"

# 3. Run the release script
bin/release X.Y.Z
```

The release script validates the changelog, updates version.rb, commits, tags, and publishes to RubyGems.

See `.claude/rules/releases.md` for detailed conventions.
