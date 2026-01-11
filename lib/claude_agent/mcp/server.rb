# frozen_string_literal: true

require "json"

module ClaudeAgent
  module MCP
    # In-process MCP server for hosting tools
    #
    # Unlike external MCP servers that run as subprocesses, SDK servers
    # run in the same Ruby process, providing better performance and
    # easier debugging.
    #
    # @example Create a server with tools
    #   add_tool = ClaudeAgent::MCP::Tool.new(
    #     name: "add",
    #     description: "Add two numbers",
    #     schema: {a: Float, b: Float}
    #   ) { |args| args["a"] + args["b"] }
    #
    #   server = ClaudeAgent::MCP::Server.new(
    #     name: "calculator",
    #     tools: [add_tool]
    #   )
    #
    # @example Use with ClaudeAgent
    #   options = ClaudeAgent::Options.new(
    #     mcp_servers: {
    #       "calculator" => {type: "sdk", instance: server}
    #     }
    #   )
    #
    class Server
      attr_reader :name, :tools

      # @param name [String] Server name
      # @param tools [Array<Tool>] Tools to expose
      def initialize(name:, tools: [])
        @name = name.to_s
        @tools = {}
        tools.each { |tool| add_tool(tool) }
      end

      # Add a tool to the server
      # @param tool [Tool] Tool to add
      # @return [void]
      def add_tool(tool)
        @tools[tool.name] = tool
      end

      # Remove a tool from the server
      # @param name [String] Tool name
      # @return [Tool, nil] Removed tool
      def remove_tool(name)
        @tools.delete(name.to_s)
      end

      # Handle an MCP message
      # @param message [Hash] MCP JSON-RPC message
      # @return [Hash] MCP JSON-RPC response
      def handle_message(message)
        method = message["method"]
        params = message["params"] || {}
        id = message["id"]

        result = case method
        when "initialize"
          handle_initialize(params)
        when "tools/list"
          handle_tools_list(params)
        when "tools/call"
          handle_tools_call(params)
        when "notifications/initialized"
          # Acknowledgement, no response needed
          return nil
        else
          return jsonrpc_error(id, -32601, "Method not found: #{method}")
        end

        jsonrpc_response(id, result)
      rescue => e
        jsonrpc_error(id, -32603, "Internal error: #{e.message}")
      end

      # Get MCP server configuration for options
      # @return [Hash]
      def to_config
        { type: "sdk", name: @name, instance: self }
      end

      private

      def handle_initialize(params)
        {
          protocolVersion: "2024-11-05",
          capabilities: {
            tools: {}
          },
          serverInfo: {
            name: @name,
            version: ClaudeAgent::VERSION
          }
        }
      end

      def handle_tools_list(params)
        {
          tools: @tools.values.map(&:to_mcp_definition)
        }
      end

      def handle_tools_call(params)
        tool_name = params["name"]
        arguments = params["arguments"] || {}

        tool = @tools[tool_name]
        unless tool
          return {
            content: [ { type: "text", text: "Unknown tool: #{tool_name}" } ],
            isError: true
          }
        end

        tool.call(arguments)
      end

      def jsonrpc_response(id, result)
        {
          jsonrpc: "2.0",
          id: id,
          result: result
        }
      end

      def jsonrpc_error(id, code, message)
        {
          jsonrpc: "2.0",
          id: id,
          error: {
            code: code,
            message: message
          }
        }
      end
    end

    # Convenience method to create a tool
    #
    # @example
    #   tool = ClaudeAgent::MCP.tool("greet", "Greet someone", {name: String}) do |args|
    #     "Hello, #{args['name']}!"
    #   end
    #
    def self.tool(name, description, schema = {}, &handler)
      Tool.new(name: name, description: description, schema: schema, &handler)
    end

    # Convenience method to create a server
    #
    # @example
    #   server = ClaudeAgent::MCP.create_server(name: "mytools", tools: [tool1, tool2])
    #
    def self.create_server(name:, tools: [])
      Server.new(name: name, tools: tools)
    end
  end
end
