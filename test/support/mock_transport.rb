# frozen_string_literal: true

# Reusable mock transport for testing Client, Query, and ControlProtocol.
#
# Usage:
#   transport = MockTransport.new(responses: [...])
#   transport = MockTransport.new  # then use add_response
#
class MockTransport < ClaudeAgent::Transport::Base
  attr_reader :written_messages, :responses

  def initialize(responses: [], track_lifecycle: false)
    super()
    @responses = responses.dup
    @written_messages = []
    @connected = false
    @input_ended = false
    @track_lifecycle = track_lifecycle
  end

  def connect(streaming: true, prompt: nil)
    @connected = true
    track(:connect, streaming: streaming, prompt: prompt) if @track_lifecycle
  end

  def write(data)
    @written_messages << JSON.parse(data)
  end

  def read_messages
    return enum_for(:read_messages) unless block_given?

    @responses.each { |response| yield response }
  end

  def end_input
    @input_ended = true
    track(:end_input) if @track_lifecycle
  end

  def close
    @connected = false
  end

  def ready?
    @connected
  end

  def connected?
    @connected
  end

  def input_ended?
    @input_ended
  end

  def add_response(response)
    @responses << response
  end

  private

  def track(type, **attrs)
    @written_messages << { type: type.to_s }.merge(attrs)
  end
end
