# MCP Tools

The ClaudeAgent Ruby SDK lets you define MCP (Model Context Protocol) tool servers that run in-process -- in the same Ruby process as your application. Unlike external MCP servers that launch as subprocesses communicating over stdio, SDK servers handle tool calls directly via method dispatch. This means faster execution, shared state with your application, and straightforward debugging.

## Block DSL (Recommended)

The most concise way to define an MCP server is the block DSL. Pass a block to `Server.new` and call `tool` to register each tool inline:

```ruby
server = ClaudeAgent::MCP::Server.new(name: "calculator") do |s|
  s.tool("add", "Add two numbers", { a: :number, b: :number }) do |args|
    (args[:a] + args[:b]).to_s
  end

  s.tool("multiply", "Multiply two numbers", { a: :number, b: :number }) do |args|
    (args[:a] * args[:b]).to_s
  end
end
```

Each call to `s.tool(name, description, schema, &handler)` creates a `ClaudeAgent::MCP::Tool` and registers it on the server. The handler block receives a **symbol-keyed** Hash of the arguments Claude provides.

## Traditional Approach

Create `Tool` objects first, then pass them to the server constructor:

```ruby
add_tool = ClaudeAgent::MCP::Tool.new(
  name: "add",
  description: "Add two numbers",
  schema: { a: Float, b: Float }
) { |args| (args[:a] + args[:b]).to_s }

subtract_tool = ClaudeAgent::MCP::Tool.new(
  name: "subtract",
  description: "Subtract two numbers",
  schema: { a: Float, b: Float }
) { |args| (args[:a] - args[:b]).to_s }

server = ClaudeAgent::MCP::Server.new(
  name: "calculator",
  tools: [add_tool, subtract_tool]
)
```

You can also add and remove tools after construction:

```ruby
server.add_tool(new_tool)
server.remove_tool("old_tool")
```

## Convenience Methods

`ClaudeAgent::MCP` provides module-level shortcuts for creating tools and servers without fully qualifying the class names:

```ruby
tool = ClaudeAgent::MCP.tool("greet", "Greet someone", { name: String }) do |args|
  "Hello, #{args[:name]}!"
end

server = ClaudeAgent::MCP.create_server(name: "greeter", tools: [tool])
```

## Tool Schema

The schema defines the JSON Schema for the tool's input parameters. Three formats are supported.

### Ruby class mapping

Pass a Hash mapping parameter names to Ruby classes. All parameters are marked as required:

```ruby
schema: { name: String, age: Integer, score: Float }
```

| Ruby Class                | JSON Schema type |
|---------------------------|------------------|
| `String`                  | `string`         |
| `Integer`                 | `integer`        |
| `Float`, `Numeric`        | `number`         |
| `TrueClass`, `FalseClass` | `boolean`        |
| `Array`                   | `array`          |
| `Hash`                    | `object`         |

### Symbol shortcuts

Use symbols instead of classes for a more compact definition:

```ruby
schema: { name: :string, count: :integer, ratio: :number, active: :boolean }
```

| Symbol                          | JSON Schema type |
|---------------------------------|------------------|
| `:string`, `:str`               | `string`         |
| `:integer`, `:int`              | `integer`        |
| `:number`, `:float`, `:numeric` | `number`         |
| `:boolean`, `:bool`             | `boolean`        |
| `:array`                        | `array`          |
| `:object`, `:hash`              | `object`         |

### Raw JSON Schema

For full control (enums, optional fields, nested objects), pass a standard JSON Schema Hash directly. The SDK detects raw schemas by the presence of a `type` or `properties` key and passes them through unchanged:

```ruby
schema: {
  type: "object",
  properties: {
    operation: { type: "string", enum: ["add", "subtract", "multiply"] },
    a: { type: "number" },
    b: { type: "number" }
  },
  required: ["operation", "a", "b"]
}
```

## Tool Annotations

MCP tool annotations provide hints to the model about tool behavior. Pass an `annotations` Hash when creating a tool:

```ruby
server = ClaudeAgent::MCP::Server.new(name: "files") do |s|
  s.tool("read_file", "Read a file", { path: :string },
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: false,
      title: "Read File"
    }
  ) do |args|
    File.read(args[:path])
  end
end
```

| Annotation        | Type    | Description                                       |
|-------------------|---------|---------------------------------------------------|
| `readOnlyHint`    | Boolean | Tool does not modify state                        |
| `destructiveHint` | Boolean | Tool may perform destructive operations           |
| `idempotentHint`  | Boolean | Repeated calls with same args produce same result |
| `openWorldHint`   | Boolean | Tool interacts with external systems              |
| `title`           | String  | Human-readable display name                       |

Annotations are omitted from the MCP definition when `nil` or empty.

## Tool Return Values

The handler block's return value is automatically formatted into the MCP response structure. Several return types are supported:

**String** -- wrapped in a text content block:

```ruby
s.tool("greet", "Greet", { name: :string }) do |args|
  "Hello, #{args[:name]}!"
end
# => { content: [{ type: "text", text: "Hello, World!" }], isError: false }
```

**Numeric or other non-String** -- converted via `to_s` and wrapped in a text content block:

```ruby
s.tool("add", "Add", { a: :number, b: :number }) do |args|
  args[:a] + args[:b]
end
# => { content: [{ type: "text", text: "7.5" }], isError: false }
```

**Hash with `:content` key** -- used as-is, letting you return custom content blocks:

```ruby
s.tool("image", "Generate image", {}) do |args|
  { content: [{ type: "image", data: base64_data, mimeType: "image/png" }] }
end
```

**Array** -- treated as a pre-built content block array:

```ruby
s.tool("multi", "Multiple outputs", {}) do |args|
  [
    { type: "text", text: "Part 1" },
    { type: "text", text: "Part 2" }
  ]
end
```

**Exceptions** -- if the handler raises, the error is caught and returned as an error response:

```ruby
s.tool("divide", "Divide", { a: :number, b: :number }) do |args|
  raise "Division by zero" if args[:b] == 0
  (args[:a] / args[:b]).to_s
end
# When b=0: { content: [{ type: "text", text: "Error: Division by zero" }], isError: true }
```

## Using with Options

To attach an MCP server to a query, pass it via the `mcp_servers` option. Each server entry is keyed by name and must include `type: "sdk"` and `instance:` pointing to the server object:

```ruby
server = ClaudeAgent::MCP::Server.new(name: "calculator") do |s|
  s.tool("add", "Add two numbers", { a: :number, b: :number }) do |args|
    (args[:a] + args[:b]).to_s
  end
end

options = ClaudeAgent::Options.new(
  mcp_servers: {
    "calculator" => { type: "sdk", instance: server }
  }
)

turn = ClaudeAgent.ask("What is 2 + 3?", options: options)
```

The server also provides a `to_config` shortcut that builds the config Hash for you:

```ruby
options = ClaudeAgent::Options.new(
  mcp_servers: {
    "calculator" => server.to_config
  }
)
```

## Global Registration

Register an MCP server globally so it is available to all queries without passing it in every `Options`:

```ruby
server = ClaudeAgent::MCP::Server.new(name: "calculator") do |s|
  s.tool("add", "Add two numbers", { a: :number, b: :number }) do |args|
    (args[:a] + args[:b]).to_s
  end
end

ClaudeAgent.register_mcp_server(server)

# Now every query can use the calculator tools
turn = ClaudeAgent.ask("What is 2 + 3?")
```

Globally registered servers are stored in `ClaudeAgent.config.default_mcp_servers` and merged into the effective `Options` for each request.

## External MCP Servers

In addition to in-process SDK servers, you can configure external MCP servers that run as subprocesses. These use the `stdio` transport type and are passed directly to the Claude Code CLI:

```ruby
options = ClaudeAgent::Options.new(
  mcp_servers: {
    "filesystem" => {
      type: "stdio",
      command: "npx",
      args: ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"]
    },
    "database" => {
      type: "stdio",
      command: "python",
      args: ["-m", "mcp_server_sqlite", "--db", "app.db"]
    }
  }
)
```

You can mix SDK and external servers in the same `mcp_servers` Hash. The SDK filters out external servers and passes their configuration to the CLI's `--mcp-config` flag, while SDK servers are handled in-process.

## MCP Elicitation

MCP elicitation allows an MCP server to request additional input from the user (or your application) during a tool call -- for example, to handle OAuth consent or collect form data.

Set the `on_elicitation` callback in your `Options`. The callback receives a request Hash and must return a response Hash:

```ruby
options = ClaudeAgent::Options.new(
  on_elicitation: ->(request, signal:) {
    # request keys:
    #   :server_name       - which MCP server triggered this
    #   :message           - display message from the server
    #   :mode              - elicitation mode
    #   :url               - URL for OAuth flows (if applicable)
    #   :elicitation_id    - unique ID for this elicitation
    #   :requested_schema  - schema describing expected input

    case request[:mode]
    when "oauth"
      # Handle OAuth flow, return approval
      { action: "approve", content: { token: "..." } }
    else
      # Decline unknown elicitation types
      { action: "decline" }
    end
  }
)
```

The callback must return a Hash with an `action` key. Supported actions:

| Action      | Description                                                        |
|-------------|--------------------------------------------------------------------|
| `"approve"` | Accept the elicitation and optionally provide `content`            |
| `"decline"` | Reject the elicitation (this is the default if no callback is set) |

If no `on_elicitation` callback is configured, all elicitation requests are declined automatically.
