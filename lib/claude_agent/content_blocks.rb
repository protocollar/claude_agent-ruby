# frozen_string_literal: true

require_relative "content_blocks/text_block"
require_relative "content_blocks/thinking_block"
require_relative "content_blocks/tool_use_block"
require_relative "content_blocks/tool_result_block"
require_relative "content_blocks/server_tool_use_block"
require_relative "content_blocks/server_tool_result_block"
require_relative "content_blocks/image_content_block"
require_relative "content_blocks/generic_block"

module ClaudeAgent
  # All content block types
  CONTENT_BLOCK_TYPES = [
    TextBlock,
    ThinkingBlock,
    ToolUseBlock,
    ToolResultBlock,
    ServerToolUseBlock,
    ServerToolResultBlock,
    ImageContentBlock,
    GenericBlock
  ].freeze
end
