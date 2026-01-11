# frozen_string_literal: true

module ClaudeAgent
  module MCP
    # Defines a tool that can be called by Claude
    #
    # @example Simple tool
    #   tool = ClaudeAgent::MCP::Tool.new(
    #     name: "greet",
    #     description: "Greet a person",
    #     schema: {name: String}
    #   ) do |args|
    #     "Hello, #{args['name']}!"
    #   end
    #
    # @example Tool with complex schema
    #   tool = ClaudeAgent::MCP::Tool.new(
    #     name: "calculate",
    #     description: "Perform arithmetic",
    #     schema: {
    #       type: "object",
    #       properties: {
    #         operation: {type: "string", enum: ["add", "subtract"]},
    #         a: {type: "number"},
    #         b: {type: "number"}
    #       },
    #       required: ["operation", "a", "b"]
    #     }
    #   ) do |args|
    #     case args["operation"]
    #     when "add" then args["a"] + args["b"]
    #     when "subtract" then args["a"] - args["b"]
    #     end
    #   end
    #
    class Tool
      attr_reader :name, :description, :schema, :handler

      # @param name [String] Tool name (must be unique within server)
      # @param description [String] Description of what the tool does
      # @param schema [Hash] Input schema (simple Ruby types or JSON Schema)
      # @param handler [Proc] Block to execute when tool is called
      def initialize(name:, description:, schema: {}, &handler)
        @name = name.to_s
        @description = description.to_s
        @schema = normalize_schema(schema)
        @handler = handler || ->(args) { raise "No handler defined for tool #{name}" }
      end

      # Call the tool with arguments
      # @param args [Hash] Tool arguments
      # @return [Hash] MCP response format
      def call(args)
        result = @handler.call(args)
        format_result(result)
      rescue => e
        format_error(e)
      end

      # Convert to MCP tool definition format
      # @return [Hash]
      def to_mcp_definition
        {
          name: @name,
          description: @description,
          inputSchema: @schema
        }
      end

      private

      # Normalize schema from simple Ruby types to JSON Schema
      def normalize_schema(schema)
        return schema if json_schema?(schema)

        # Convert simple {name: Type} format to JSON Schema
        if schema.is_a?(Hash) && schema.values.all? { |v| v.is_a?(Class) || v.is_a?(Module) }
          {
            type: "object",
            properties: schema.transform_values { |type| type_to_schema(type) },
            required: schema.keys.map(&:to_s)
          }
        else
          schema
        end
      end

      def json_schema?(schema)
        return false unless schema.is_a?(Hash)

        schema.key?(:type) || schema.key?("type") ||
          schema.key?(:properties) || schema.key?("properties")
      end

      def type_to_schema(type)
        case type.to_s
        when "String"
          { type: "string" }
        when "Integer"
          { type: "integer" }
        when "Float", "Numeric"
          { type: "number" }
        when "TrueClass", "FalseClass"
          { type: "boolean" }
        when "Array"
          { type: "array" }
        when "Hash"
          { type: "object" }
        else
          { type: "string" }
        end
      end

      def format_result(result)
        content = case result
        when String
          [ { type: "text", text: result } ]
        when Hash
          result[:content] || [ { type: "text", text: result.to_json } ]
        when Array
          result
        else
          [ { type: "text", text: result.to_s } ]
        end

        { content: content, isError: false }
      end

      def format_error(error)
        {
          content: [ { type: "text", text: "Error: #{error.message}" } ],
          isError: true
        }
      end
    end
  end
end
