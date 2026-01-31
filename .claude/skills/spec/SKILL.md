---
name: spec
description: Manage the SDK feature parity specification. Use 'update' to regenerate SPEC.md from current implementations, or 'complete' to implement missing features.
argument-hint: [update|complete]
disable-model-invocation: true
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, TodoWrite, Task, AskUserQuestion, EnterPlanMode
---

# SDK Feature Parity Management

Manage the feature parity specification for the TypeScript, Python, and Ruby Claude Agent SDKs.

## Reference SDKs

Ensure reference SDKs are current before starting any workflow:

```bash
bin/update-reference-sdks
```

This clones/updates:
- Python SDK from GitHub -> `vendor/claude-agent-sdk-python`
- TypeScript SDK from npm -> `vendor/claude-agent-sdk-npm`
- TypeScript SDK repo from GitHub -> `vendor/claude-agent-sdk-typescript` (changelog/releases)

## Key Source Files

**TypeScript SDK (Primary Reference)**
- `vendor/claude-agent-sdk-npm/sdk.d.ts` - Complete API surface with all types
- `vendor/claude-agent-sdk-typescript/CHANGELOG.md` - Release changelog

**Python SDK**
- `vendor/claude-agent-sdk-python/src/claude_agent_sdk/types.py` - Type definitions
- `vendor/claude-agent-sdk-python/src/claude_agent_sdk/_internal/` - Internal implementation

**Ruby SDK (This Repository)**
- `lib/claude_agent/` - All implementation files

## Mode Selection

Based on the first argument:

- **update**: Follow the workflow in [commands/update.md](commands/update.md)
- **complete**: Follow the workflow in [commands/complete.md](commands/complete.md)
- If no argument or unrecognized: ask the user which mode they want
