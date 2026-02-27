# frozen_string_literal: true

module ClaudeAgent
  # Enumerable collection of {LiveToolActivity} entries with auto-wiring.
  #
  # Attaches to an {EventHandler} or {Client} and automatically tracks
  # tool lifecycle events (:tool_use, :tool_result, :tool_progress),
  # maintaining a live view of active and completed tools.
  #
  # @example Specific callbacks
  #   tracker = ToolActivityTracker.attach(client)
  #   tracker.on_start    { |entry| puts "▸ #{entry.display_label}" }
  #   tracker.on_progress { |entry| puts "  #{entry.elapsed&.round(1)}s..." }
  #   tracker.on_complete { |entry| puts "✓ #{entry.display_label}" }
  #
  # @example Catch-all callback
  #   tracker.on_change { |event, entry| log(event, entry.id) }
  #
  # @example Poll running tools
  #   tracker.running.each { |t| render_spinner(t) }
  #   tracker.done.each { |t| render_checkmark(t) }
  #
  class ToolActivityTracker
    include Enumerable

    # Create a tracker and wire it to an EventHandler or Client.
    #
    # @param target [EventHandler, Client] The event source to wire into
    # @return [ToolActivityTracker]
    def self.attach(target)
      tracker = new
      handler = target.is_a?(EventHandler) ? target : target.event_handler
      tracker.send(:wire, handler)
      tracker
    end

    def initialize
      @entries = []
      @index = {}
      @callbacks = {}
    end

    # Register a callback for when a tool starts running.
    #
    # @yield [entry] Called when a tool use is detected
    # @yieldparam entry [LiveToolActivity] The new entry
    # @return [self]
    def on_start(&block)
      @callbacks[:started] = block
      self
    end

    # Register a callback for when a tool completes (success or error).
    #
    # @yield [entry] Called when a tool result is received
    # @yieldparam entry [LiveToolActivity] The completed entry
    # @return [self]
    def on_complete(&block)
      @callbacks[:completed] = block
      self
    end

    # Register a callback for tool progress updates.
    #
    # @yield [entry] Called when elapsed time is updated
    # @yieldparam entry [LiveToolActivity] The updated entry
    # @return [self]
    def on_progress(&block)
      @callbacks[:progress] = block
      self
    end

    # Register a catch-all callback for any state change.
    #
    # Fires with :started, :completed, or :progress and the affected entry.
    # Fires in addition to specific callbacks (on_start, on_complete, on_progress).
    #
    # @yield [event, entry] Called on each state change
    # @yieldparam event [Symbol] :started, :completed, or :progress
    # @yieldparam entry [LiveToolActivity] The affected entry
    # @return [self]
    def on_change(&block)
      @callbacks[:change] = block
      self
    end

    # @yield [LiveToolActivity]
    # @return [Enumerator<LiveToolActivity>]
    def each(&block)
      @entries.each(&block)
    end

    # Number of tracked activities.
    # @return [Integer]
    def size
      @entries.size
    end

    # Whether there are no tracked activities.
    # @return [Boolean]
    def empty?
      @entries.empty?
    end

    # Look up a LiveToolActivity by tool use ID.
    #
    # @param id [String] Tool use ID
    # @return [LiveToolActivity, nil]
    def find_by_id(id)
      @index[id]
    end

    alias_method :[], :find_by_id

    # All currently running activities.
    # @return [Array<LiveToolActivity>]
    def running
      @entries.select(&:running?)
    end

    # All completed (success) activities.
    # @return [Array<LiveToolActivity>]
    def done
      @entries.select(&:done?)
    end

    # All errored activities.
    # @return [Array<LiveToolActivity>]
    def errored
      @entries.select(&:error?)
    end

    # Clear all tracked state. Call between turns.
    # @return [void]
    def reset!
      @entries.clear
      @index.clear
    end

    private

    def wire(handler)
      handler.on(:tool_use) { |tool_use| handle_tool_use(tool_use) }
      handler.on(:tool_result) { |tool_result, _tool_use| handle_tool_result(tool_result) }
      handler.on(:tool_progress) { |message| handle_tool_progress(message) }
    end

    def emit(event, entry)
      @callbacks[event]&.call(entry)
      @callbacks[:change]&.call(event, entry)
    end

    def handle_tool_use(tool_use)
      entry = LiveToolActivity.new(tool_use)
      @entries << entry
      @index[tool_use.id] = entry
      emit(:started, entry)
    end

    def handle_tool_result(tool_result)
      entry = @index[tool_result.tool_use_id]
      return unless entry

      entry.complete!(tool_result)
      emit(:completed, entry)
    end

    def handle_tool_progress(message)
      entry = @index[message.tool_use_id]
      return unless entry

      entry.update_elapsed(message.elapsed_time_seconds)
      emit(:progress, entry)
    end
  end
end
