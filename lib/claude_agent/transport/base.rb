# frozen_string_literal: true

module ClaudeAgent
  module Transport
    # Abstract base class for transport implementations
    #
    # Transports handle the low-level communication with Claude Code CLI
    # or other backends. They are responsible for:
    # - Starting/stopping the connection
    # - Writing messages (JSON Lines format)
    # - Reading and parsing responses
    #
    # @abstract Subclass and implement all abstract methods
    #
    class Base
      # Establish the connection
      # @return [void]
      def connect
        raise NotImplementedError, "#{self.class} must implement #connect"
      end

      # Write data to the transport
      # @param data [String] JSON string to write (newline will be added)
      # @return [void]
      def write(data)
        raise NotImplementedError, "#{self.class} must implement #write"
      end

      # Read messages from the transport
      # @yield [Hash] Parsed JSON messages
      # @return [Enumerator] If no block given
      def read_messages(&block)
        raise NotImplementedError, "#{self.class} must implement #read_messages"
      end

      # Signal end of input (close stdin for subprocess)
      # @return [void]
      def end_input
        raise NotImplementedError, "#{self.class} must implement #end_input"
      end

      # Close the transport and cleanup resources
      # @return [void]
      def close
        raise NotImplementedError, "#{self.class} must implement #close"
      end

      # Check if the transport is ready for communication
      # @return [Boolean]
      def ready?
        raise NotImplementedError, "#{self.class} must implement #ready?"
      end

      # Check if the transport is connected
      # @return [Boolean]
      def connected?
        raise NotImplementedError, "#{self.class} must implement #connected?"
      end
    end
  end
end
