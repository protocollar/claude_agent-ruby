# frozen_string_literal: true

require_relative "messages/conversation"
require_relative "messages/result"
require_relative "messages/system"
require_relative "messages/streaming"
require_relative "messages/tool_lifecycle"
require_relative "messages/hook_lifecycle"
require_relative "messages/task_lifecycle"
require_relative "messages/generic"

module ClaudeAgent
  # All message types
  MESSAGE_TYPES = [
    UserMessage,
    UserMessageReplay,
    AssistantMessage,
    SystemMessage,
    ResultMessage,
    StreamEvent,
    CompactBoundaryMessage,
    StatusMessage,
    ToolProgressMessage,
    HookResponseMessage,
    AuthStatusMessage,
    TaskNotificationMessage,
    HookStartedMessage,
    HookProgressMessage,
    ToolUseSummaryMessage,
    FilesPersistedEvent,
    TaskStartedMessage,
    TaskProgressMessage,
    RateLimitEvent,
    PromptSuggestionMessage,
    ElicitationCompleteMessage,
    LocalCommandOutputMessage,
    APIRetryMessage,
    GenericMessage
  ].freeze
end
