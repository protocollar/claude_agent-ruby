# frozen_string_literal: true

module ClaudeAgent
  # Tracks cumulative usage statistics across multiple conversation turns
  #
  # Token counts are summed across all turns. Cost and turn count reflect
  # the session-cumulative values from the most recent result (the CLI
  # already accumulates these across the session).
  #
  # @example Via Client
  #   ClaudeAgent::Client.open do |client|
  #     client.send_message("Hello")
  #     client.receive_response.each { |m| }
  #
  #     client.send_message("Follow up")
  #     client.receive_response.each { |m| }
  #
  #     usage = client.cumulative_usage
  #     puts "Tokens: #{usage.input_tokens} in / #{usage.output_tokens} out"
  #     puts "Cost: $#{usage.total_cost_usd}"
  #     puts "Turns: #{usage.num_turns}"
  #   end
  #
  # @example Standalone
  #   tracker = ClaudeAgent::CumulativeUsage.new
  #   messages.each { |msg| tracker.track(msg) }
  #   puts tracker.to_h
  #
  class CumulativeUsage
    attr_reader :input_tokens, :output_tokens,
                :cache_read_input_tokens, :cache_creation_input_tokens,
                :total_cost_usd, :num_turns,
                :duration_ms, :duration_api_ms

    def initialize
      @mutex = Mutex.new
      @input_tokens = 0
      @output_tokens = 0
      @cache_read_input_tokens = 0
      @cache_creation_input_tokens = 0
      @total_cost_usd = 0.0
      @num_turns = 0
      @duration_ms = 0
      @duration_api_ms = 0
    end

    # Update cumulative usage from a message
    #
    # Only processes {ResultMessage} instances; other message types are ignored.
    #
    # @param message [Object] Any message object
    # @return [void]
    def track(message)
      return unless message.is_a?(ResultMessage)

      @mutex.synchronize do
        if message.usage
          @input_tokens += message.usage[:input_tokens].to_i
          @output_tokens += message.usage[:output_tokens].to_i
          @cache_read_input_tokens += message.usage[:cache_read_input_tokens].to_i
          @cache_creation_input_tokens += message.usage[:cache_creation_input_tokens].to_i
        end

        # Cost and turn count are session-cumulative from the CLI
        @total_cost_usd = message.total_cost_usd if message.total_cost_usd
        @num_turns = message.num_turns if message.num_turns

        # Durations are per-turn, sum them
        @duration_ms += message.duration_ms.to_i
        @duration_api_ms += message.duration_api_ms.to_i
      end
    end

    # Reset all counters to zero
    #
    # @return [void]
    def reset!
      @mutex.synchronize do
        @input_tokens = 0
        @output_tokens = 0
        @cache_read_input_tokens = 0
        @cache_creation_input_tokens = 0
        @total_cost_usd = 0.0
        @num_turns = 0
        @duration_ms = 0
        @duration_api_ms = 0
      end
    end

    # @return [Hash] All tracked fields as a hash
    def to_h
      @mutex.synchronize do
        {
          input_tokens: @input_tokens,
          output_tokens: @output_tokens,
          cache_read_input_tokens: @cache_read_input_tokens,
          cache_creation_input_tokens: @cache_creation_input_tokens,
          total_cost_usd: @total_cost_usd,
          num_turns: @num_turns,
          duration_ms: @duration_ms,
          duration_api_ms: @duration_api_ms
        }
      end
    end
  end
end
