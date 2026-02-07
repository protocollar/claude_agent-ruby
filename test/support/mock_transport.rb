# frozen_string_literal: true

# Reusable mock transport for testing Client, Query, and ControlProtocol.
#
# Auto-responds to control_request messages (e.g. initialize) so that
# ControlProtocol.start works without hanging.
#
# Uses a blocking Queue so the reader thread stays alive to process
# dynamic responses (e.g. control_request → control_response handshake).
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
    @message_queue = Queue.new
  end

  def connect(streaming: true, prompt: nil)
    @connected = true
    # Push pre-set responses into the blocking queue
    @responses.each { |r| @message_queue.push(r) }
    track(:connect, streaming: streaming, prompt: prompt) if @track_lifecycle
  end

  def write(data)
    parsed = JSON.parse(data)
    @written_messages << parsed

    # Auto-respond to control requests (e.g. initialize) so tests don't hang
    if parsed["type"] == "control_request"
      request_id = parsed["request_id"]
      @message_queue.push({
        "type" => "control_response",
        "response" => {
          "subtype" => "success",
          "request_id" => request_id,
          "response" => {}
        }
      })
    end
  end

  def read_messages
    return enum_for(:read_messages) unless block_given?

    # Blocking queue read - stays alive until nil sentinel from end_input
    loop do
      msg = @message_queue.pop
      break if msg.nil?
      yield msg
    end
  end

  def end_input
    @input_ended = true
    @message_queue.push(nil) # sentinel to unblock read_messages
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
    @message_queue.push(response) if @connected
  end

  private

  def track(type, **attrs)
    @written_messages << { type: type.to_s }.merge(attrs)
  end
end
