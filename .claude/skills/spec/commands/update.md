# Update SDK Specification

Update SPEC.md to reflect the current feature parity between the TypeScript, Python, and Ruby Claude Agent SDKs.

## Step 1: Update Reference SDKs

Run `bin/update-reference-sdks` to ensure all reference SDKs are current.

## Step 2: Research Official Documentation

Use the `claude-code-guide` agent to check for new or updated SDK features:

```
Task(subagent_type: "claude-code-guide", prompt: "What are all the features and options in the Claude Agent SDK? Include configuration options, hooks, permissions, MCP support, and control protocol methods.")
```

This helps catch features documented but not yet in SDK source files.

## Step 3: Analyze All Three SDKs

Read and compare the key source files listed in SKILL.md. Pay special attention to:
- TypeScript `sdk.d.ts` as the authoritative API surface
- TypeScript `CHANGELOG.md` for recently added features
- Python `types.py` for implementation patterns
- All Ruby SDK files for current implementation status

## Step 4: Update SPEC.md

1. **Reference Versions** - Update TypeScript SDK version and Python SDK commit
2. **Feature Tables** - Update all markers based on current implementations
3. **New Features** - Add any new features found in the TypeScript SDK
4. **Removed Features** - Remove any deprecated features

## Guidelines

- Check every field and option in each SDK
- TypeScript sdk.d.ts is the authoritative reference
- Preserve the existing table structure and markdown formatting
- Always update the reference version info at the top
- Note significant changes after updating

## Output

Provide a brief summary of:
- SDK versions checked
- New features added to the spec
- Features removed from the spec
- Notable gaps in the Ruby SDK
