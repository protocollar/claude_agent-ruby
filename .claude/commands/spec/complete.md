---
description: Implement missing Ruby SDK features identified in SPEC.md to achieve full parity with TypeScript/Python SDKs
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, TodoWrite, Task, AskUserQuestion, EnterPlanMode
---

# Complete SDK Feature Parity

You are implementing missing features in the Ruby SDK to achieve full parity with the official TypeScript and Python Claude Agent SDKs.

## Step 1: Identify Missing Features

Read SPEC.md and identify all features where the Ruby SDK shows ❌ (not implemented):

```
Read SPEC.md
```

Create a prioritized list of missing features:
1. **High Priority** - Features implemented in BOTH TypeScript and Python SDKs
2. **Medium Priority** - Features only in TypeScript SDK (Python also missing)
3. **Low Priority** - TypeScript-only features that may be JS-specific

Use TodoWrite to track the features to implement.

## Step 2: Research Each Feature

For each missing feature, gather complete context before planning:

### 2a. Official Documentation

Use the `claude-code-guide` agent to understand the feature's intended behavior:

```
Task(subagent_type: "claude-code-guide", prompt: "How does [feature] work in the Claude Agent SDK? What are all the options, behaviors, and edge cases?")
```

### 2b. TypeScript Implementation

Read the TypeScript type definitions to understand the API surface:
- `vendor/claude-agent-sdk-npm/sdk.d.ts`

### 2c. Python Implementation (if available)

If Python has the feature, read their implementation for patterns:
- `vendor/claude-agent-sdk-python/src/claude_agent_sdk/types.py`
- `vendor/claude-agent-sdk-python/src/claude_agent_sdk/_internal/`

## Step 3: Clarify Requirements

Use AskUserQuestion to resolve any ambiguities:

- Implementation approach choices
- Ruby-specific design decisions
- Whether certain features should be skipped (e.g., JS-specific)
- Priority ordering if time-constrained

## Step 4: Enter Plan Mode

Enter plan mode to design the implementation:

```
EnterPlanMode
```

The plan should include:
- Which files to create or modify
- Data structures (use `Data.define` for immutable types)
- Public API design
- Test coverage requirements
- Any breaking changes or deprecations

## Step 5: Implement Features

After plan approval, implement each feature:

1. Add types/data structures
2. Update Options if new configuration needed
3. Implement core functionality
4. Add CLI argument mapping (if applicable)
5. Update RBS type signatures in `sig/` directory
6. Write unit tests in `test/claude_agent/`
7. Write integration tests in `test/integration/` for features that interact with CLI/API
8. Update SPEC.md to mark feature as ✅

### Testing Requirements

- **Unit tests** - For all new types, data structures, and internal logic
- **Integration tests** - Required for anything that:
  - Spawns the CLI subprocess
  - Sends/receives messages via the control protocol
  - Interacts with MCP servers
  - Uses file checkpointing or session management

## Step 6: Update Specification

After implementing features, run `/spec:update` to refresh SPEC.md with the new implementation status.

## Output

Provide a summary of:
- Features implemented
- Any features skipped (with reasons)
- Breaking changes introduced
- Test coverage added
- Remaining gaps (if any)
