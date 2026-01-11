# Git Etiquette

## Commit Messages

- Never reference Claude, Anthropic, or AI agents in commit messages
- Always create atomic commits that do not leave the app in a broken state

## Conventional Commits Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

## Commit Types

| Label       | Purpose                                                          |
|-------------|------------------------------------------------------------------|
| `feat:`     | New feature for the user (MINOR version bump)                    |
| `fix:`      | Bug fix for the user (PATCH version bump)                        |
| `docs:`     | Documentation changes                                            |
| `style:`    | Formatting, missing semicolons, etc. (no production code change) |
| `refactor:` | Refactoring production code (e.g., renaming a variable)          |
| `perf:`     | Performance improvements                                         |
| `test:`     | Adding/refactoring tests (no production code change)             |
| `build:`    | Build system or external dependency changes                      |
| `ci:`       | CI configuration changes                                         |
| `chore:`    | Other tasks (no production code change)                          |

## Scope (Optional)

Use scope to specify what area of the codebase is affected:

```bash
feat(client): add session resumption support
fix(transport): handle CLI process timeout
refactor(mcp): extract schema normalization to module
```

## Breaking Changes

Indicate breaking changes using either method:

```bash
# Method 1: Add ! before the colon
feat!: change Options class to use keyword arguments
feat(hooks)!: rename callback parameter to handler

# Method 2: BREAKING CHANGE footer
feat: restructure message content blocks

BREAKING CHANGE: ToolUseBlock now returns input as Hash instead of JSON string
```

## Multi-line Commits

For complex changes, add a body and/or footer:

```bash
fix(protocol): resolve nil error in message parsing

The parser was failing when content blocks had no text field.
Added nil check and default to empty string.

Fixes: #42
```

## Examples

```bash
feat: add streaming support to Query interface
feat(client): add session resumption support
fix: resolve timeout error in subprocess transport
fix(mcp)!: change tool schema format
docs: update README with hook examples
style: fix indentation in control_protocol.rb
refactor: extract JSON parsing to MessageParser
perf: reduce memory allocation in message streaming
test: add specs for permission callbacks
build: bump minimum Ruby version to 3.2
ci: add integration test workflow
chore: update rubocop configuration
```
