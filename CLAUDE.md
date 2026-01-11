# ClaudeAgent Ruby SDK

Ruby SDK for building autonomous AI agents that interact with Claude Code CLI.

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
bin/rbs-validate                   # Validate RBS signatures
bin/release VERSION                # Release gem (e.g., bin/release 1.2.0)
```

## Architecture

| Component                   | Purpose                                            |
|-----------------------------|----------------------------------------------------|
| `Query`                     | One-shot stateless prompts                         |
| `Client`                    | Multi-turn bidirectional conversations             |
| `ControlProtocol`           | Handles handshake, hooks, permissions, MCP routing |
| `Transport::Subprocess`     | Spawns CLI, manages stdin/stdout                   |
| `MCP::Tool` / `MCP::Server` | Custom tool definitions                            |

## Conventions

- **Immutable data types**: All messages and options use `Data.define`
- **Frozen string literals**: Every file starts with `# frozen_string_literal: true`
- **Message polymorphism**: Use `case` statements or `is_a?()` for content block types
- **Error hierarchy**: All errors inherit from `ClaudeAgent::Error` with context (exit code, stderr, etc.)
- **Protocol flow**: Transport → ControlProtocol → MessageParser → typed message objects

## Key Patterns

```ruby
# One-shot query
result = ClaudeAgent.query("prompt", model: "sonnet")

# Interactive client
client = ClaudeAgent::Client.new(options)
client.send_message("prompt") { |msg| handle(msg) }

# Content blocks are polymorphic
message.content.each do |block|
  case block
  when ClaudeAgent::TextBlock then ...
  when ClaudeAgent::ToolUseBlock then ...
  end
end
```

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
