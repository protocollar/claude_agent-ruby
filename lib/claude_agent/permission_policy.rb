# frozen_string_literal: true

module ClaudeAgent
  # Declarative permission policy builder.
  #
  # Compiles allow/deny rules into a `can_use_tool` lambda for use
  # with Options and Conversation. Rules are evaluated in order;
  # first match wins.
  #
  # @example Basic usage
  #   policy = ClaudeAgent::PermissionPolicy.new do |p|
  #     p.allow "Read", "Grep", "Glob"
  #     p.deny "Bash", message: "Bash not allowed"
  #     p.deny_all
  #   end
  #
  # @example With regex matching
  #   policy = ClaudeAgent::PermissionPolicy.new do |p|
  #     p.allow_matching(/^mcp__/)
  #     p.deny_all
  #   end
  #
  # @example With custom handler for unmatched tools
  #   policy = ClaudeAgent::PermissionPolicy.new do |p|
  #     p.allow "Read"
  #     p.ask { |name, input, ctx| PermissionResultAllow.new }
  #   end
  #
  # @example Module-level convenience
  #   ClaudeAgent.permissions do |p|
  #     p.allow "Read", "Grep"
  #     p.deny "Bash"
  #   end
  #
  class PermissionPolicy
    # @param block [Proc] DSL block yielding self
    def initialize(&block)
      @rules = []
      @fallback = nil
      yield self if block_given?
    end

    # Allow specific tools by exact name.
    #
    # @param tool_names [Array<String>] Tool names to allow
    # @return [self]
    def allow(*tool_names)
      tool_names.flatten.each do |name|
        @rules << { type: :exact, name: name.to_s, action: :allow }
      end
      self
    end

    # Deny specific tools by exact name.
    #
    # @param tool_names [Array<String>] Tool names to deny
    # @param message [String] Denial message
    # @param interrupt [Boolean] Whether to interrupt the conversation
    # @return [self]
    def deny(*tool_names, message: "", interrupt: false)
      tool_names.flatten.each do |name|
        @rules << { type: :exact, name: name.to_s, action: :deny, message: message, interrupt: interrupt }
      end
      self
    end

    # Allow tools matching a pattern.
    #
    # @param pattern [Regexp, String] Pattern to match against tool names
    # @return [self]
    def allow_matching(pattern)
      @rules << { type: :pattern, pattern: to_regexp(pattern), action: :allow }
      self
    end

    # Deny tools matching a pattern.
    #
    # @param pattern [Regexp, String] Pattern to match against tool names
    # @param message [String] Denial message
    # @param interrupt [Boolean] Whether to interrupt the conversation
    # @return [self]
    def deny_matching(pattern, message: "", interrupt: false)
      @rules << { type: :pattern, pattern: to_regexp(pattern), action: :deny, message: message, interrupt: interrupt }
      self
    end

    # Set a custom handler for tools that don't match any rule.
    #
    # @yield [name, input, context] Called for unmatched tools
    # @return [self]
    def ask(&handler)
      @fallback = handler
      self
    end

    # Set fallback to allow all unmatched tools.
    # @return [self]
    def allow_all
      @fallback = :allow
      self
    end

    # Set fallback to deny all unmatched tools.
    #
    # @param message [String] Denial message for unmatched tools
    # @return [self]
    def deny_all(message: "Denied by policy")
      @fallback = { action: :deny, message: message }
      self
    end

    # Compile this policy into a `can_use_tool` lambda.
    #
    # @return [Proc] Lambda compatible with Options#can_use_tool
    def to_can_use_tool
      rules = @rules.dup.freeze
      fallback = @fallback

      ->(tool_name, tool_input, context) {
        # Check rules in order, first match wins
        rules.each do |rule|
          next unless matches?(rule, tool_name)

          case rule[:action]
          when :allow
            return PermissionResultAllow.new
          when :deny
            return PermissionResultDeny.new(message: rule[:message], interrupt: rule[:interrupt])
          end
        end

        # No rule matched, use fallback
        case fallback
        when :allow
          PermissionResultAllow.new
        when Hash
          PermissionResultDeny.new(message: fallback[:message])
        when Proc
          fallback.call(tool_name, tool_input, context)
        else
          # Default: allow (no policy restriction)
          PermissionResultAllow.new
        end
      }
    end

    # Whether any rules have been defined.
    # @return [Boolean]
    def empty?
      @rules.empty? && @fallback.nil?
    end

    private

    def matches?(rule, tool_name)
      case rule[:type]
      when :exact
        rule[:name] == tool_name.to_s
      when :pattern
        rule[:pattern].match?(tool_name.to_s)
      else
        false
      end
    end

    def to_regexp(pattern)
      case pattern
      when Regexp then pattern
      when String then Regexp.new(pattern)
      else raise ArgumentError, "Pattern must be a Regexp or String, got #{pattern.class}"
      end
    end
  end
end
