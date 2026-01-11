---
description: Update SPEC.md with latest feature parity comparison across TypeScript, Python, and Ruby SDKs
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, TodoWrite, Task
---

# Update SDK Specification Document

You are updating the SPEC.md file to reflect the current feature parity between the TypeScript, Python, and Ruby Claude Agent SDKs.

## Step 1: Update Reference SDKs

First, ensure the reference SDKs are up to date:

```bash
bin/update-reference-sdks
```

This clones/updates:
- Python SDK from GitHub → `vendor/claude-agent-sdk-python`
- TypeScript SDK from npm → `vendor/claude-agent-sdk-npm`

## Step 2: Research Official Documentation

Use the `claude-code-guide` agent to check for any new or updated SDK features:

```
Task(subagent_type: "claude-code-guide", prompt: "What are all the features and options in the Claude Agent SDK? Include configuration options, hooks, permissions, MCP support, and control protocol methods.")
```

This helps catch features that may be documented but not yet in the SDK source files.

## Step 3: Analyze All Three SDKs

Read and compare the following files:

### TypeScript SDK (Primary Reference)
- `vendor/claude-agent-sdk-npm/sdk.d.ts` - Complete API surface with all types

### Python SDK
- `vendor/claude-agent-sdk-python/src/claude_agent_sdk/types.py` - Type definitions

### Ruby SDK (This Repository)
Key files to check:
- `lib/claude_agent/options.rb` - Configuration options
- `lib/claude_agent/messages.rb` - Message types
- `lib/claude_agent/content_blocks.rb` - Content block types
- `lib/claude_agent/types.rb` - Additional types
- `lib/claude_agent/hooks.rb` - Hook types
- `lib/claude_agent/permissions.rb` - Permission types
- `lib/claude_agent/control_protocol.rb` - Control protocol
- `lib/claude_agent/sandbox_settings.rb` - Sandbox config
- `lib/claude_agent/mcp/server.rb` - MCP server
- `lib/claude_agent/mcp/tool.rb` - MCP tools
- `lib/claude_agent/client.rb` - Client class
- `lib/claude_agent/errors.rb` - Error types

## Step 4: Update SPEC.md

Update the existing SPEC.md file with:

1. **Reference Versions** - Update TypeScript SDK version and Python SDK commit
2. **Feature Tables** - Update all ✅/❌ markers based on current implementations
3. **New Features** - Add any new features found in the TypeScript SDK
4. **Removed Features** - Remove any deprecated features

### Categories to Compare

1. Options/Configuration
2. Message Types
3. Content Blocks
4. Control Protocol
5. Hooks
6. Permissions
7. MCP Support
8. Sessions
9. Subagents
10. Sandbox Settings
11. Error Handling
12. Client API

## Guidelines

- **Be thorough** - Check every field and option in each SDK
- **TypeScript is authoritative** - The TypeScript sdk.d.ts is the most complete reference
- **Preserve format** - Keep the existing table structure and markdown formatting
- **Update versions** - Always update the reference version info at the top
- **Note changes** - If significant changes are found, mention them after updating

## Output

After updating SPEC.md, provide a brief summary of:
- SDK versions checked
- Any new features added to the spec
- Any features removed from the spec
- Any notable gaps in the Ruby SDK
