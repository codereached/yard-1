module YARD::TypeInference
  class AbstractValue
    attr_reader :types
    attr_accessor :constant

    def initialize
      @forward = []
      @types = []
      @constant = false
    end

    def add_type(type)
      raise ArgumentError, "invalid type: #{type}" unless type.is_a?(Type)
      @types << type unless @types.include?(type)
      @forward.each do |fwd|
        fwd.add_type(type)
      end
    end

    def propagate(target)
      raise ArgumentError, "target is constant: #{target.inspect}" if target.constant
      return if target == self
      # raise ArgumentError, "target is self: #{target.inspect} == #{self.inspect}" if target == self
      raise ArgumentError, "invalid target: #{target}" unless target.is_a?(AbstractValue)
      @forward << target unless @forward.include?(target)
      @types.each do |type|
        target.add_type(type)
      end
    end

    def type_string
      types.map(&:path).join(', ')
    end

    class << self
      def single_type(type)
        av = AbstractValue.new
        av.add_type(type)
        av.constant = true
        av
      end

      def nil_type
        single_type(InstanceType.new("::NilClass"))
      end
    end
  end
end
