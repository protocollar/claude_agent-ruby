# Complete SDK Feature Parity

Implement missing features in the Ruby SDK to achieve full parity with the official TypeScript and Python Claude Agent SDKs.

## Step 1: Identify Missing Features

Read SPEC.md and identify all features where the Ruby SDK is not implemented.

Create a prioritized list:
1. **High Priority** - Features implemented in BOTH TypeScript and Python SDKs
2. **Medium Priority** - Features only in TypeScript SDK (Python also missing)
3. **Low Priority** - TypeScript-only features that may be JS-specific

Use TodoWrite to track the features to implement.

## Step 2: Research Each Feature

Gather complete context before planning:

### 2a. Official Documentation

Use the `claude-code-guide` agent to understand each feature's intended behavior:

```
Task(subagent_type: "claude-code-guide", prompt: "How does [feature] work in the Claude Agent SDK? What are all the options, behaviors, and edge cases?")
```

### 2b. Reference Implementations

Read the TypeScript type definitions and changelog listed in SKILL.md to understand the API surface and when features were added. If Python has the feature, read their implementation for patterns.

## Step 3: Clarify Requirements

Use AskUserQuestion to resolve ambiguities:
- Implementation approach choices
- Ruby-specific design decisions
- Whether certain features should be skipped (e.g., JS-specific)
- Priority ordering if time-constrained

## Step 4: Enter Plan Mode

Enter plan mode to design the implementation. The plan should include:
- Which files to create or modify
- Data structures
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
8. Update SPEC.md to mark feature as complete

### Testing Requirements

- **Unit tests** - For all new types, data structures, and internal logic
- **Integration tests** - Required for anything that spawns the CLI subprocess, sends/receives messages via the control protocol, interacts with MCP servers, or uses file checkpointing/session management

## Step 6: Update Specification

After implementing features, run `/spec update` to refresh SPEC.md with the new implementation status.

## Output

Provide a summary of:
- Features implemented
- Features skipped (with reasons)
- Breaking changes introduced
- Test coverage added
- Remaining gaps (if any)
