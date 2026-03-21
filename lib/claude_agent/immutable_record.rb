# frozen_string_literal: true

module ClaudeAgent
  # Base class for immutable value types.
  #
  # Provides the same guarantees as Data.define (frozen at construction,
  # structural equality, pattern matching) with plain inheritance so
  # modules can be included normally and RBS signatures use real supertypes.
  #
  # @example
  #   class TextBlock < ImmutableRecord
  #     attribute :text
  #
  #     def type = :text
  #     def to_h = { type: "text", text: text }
  #   end
  #
  #   block = TextBlock.new(text: "hello")
  #   block.text     # => "hello"
  #   block.frozen?  # => true
  #
  class ImmutableRecord
    class << self
      # Copy parent attributes to subclass so multi-level inheritance works.
      def inherited(subclass)
        super
        subclass.instance_variable_set(:@attributes, (_attributes || []).dup)
      end

      # Declare a named attribute on this type.
      #
      # @param name [Symbol] attribute name
      # @param default [Object] default value; omit for required attributes
      def attribute(name, default: :__required__)
        @attributes ||= []
        @attributes << { name: name, default: default }
        attr_reader name
      end

      # @return [Array<Symbol>] attribute names
      def members
        (_attributes || []).map { |a| a[:name] }.freeze
      end

      private

      def _attributes
        @attributes
      end
    end

    # Build an instance from keyword arguments and freeze it.
    #
    # @raise [ArgumentError] if a required attribute is missing
    def initialize(**kwargs)
      self.class.send(:_attributes).each do |attr|
        name = attr[:name]
        if kwargs.key?(name)
          instance_variable_set(:"@#{name}", kwargs[name])
        elsif attr[:default] != :__required__
          value = attr[:default]
          value = value.dup if value.is_a?(Array) || value.is_a?(Hash)
          instance_variable_set(:"@#{name}", value)
        else
          raise ArgumentError, "missing keyword: #{name}"
        end
      end
      freeze
    end

    # Structural equality.
    def ==(other)
      other.is_a?(self.class) && _attribute_values == other._attribute_values
    end
    alias eql? ==

    # Hash code consistent with structural equality.
    def hash
      [ self.class, _attribute_values ].hash
    end

    # Pattern matching support. Unknown keys are silently ignored (unlike
    # Data.define which aborts on unknown members), allowing modules to
    # add virtual keys via super.
    #
    # @param keys [Array<Symbol>, nil] requested keys, or nil for all
    # @return [Hash<Symbol, Object>]
    def deconstruct_keys(keys)
      members = self.class.members
      if keys.nil?
        members.each_with_object({}) { |n, h| h[n] = instance_variable_get(:"@#{n}") }
      else
        keys.each_with_object({}) { |n, h| h[n] = instance_variable_get(:"@#{n}") if members.include?(n) }
      end
    end

    protected

    def _attribute_values
      self.class.members.map { |n| instance_variable_get(:"@#{n}") }
    end
  end
end
