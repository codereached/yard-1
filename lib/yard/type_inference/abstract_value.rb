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
        add_type_to_abstract_value(type, fwd)
      end
    end

    def propagate(target)
      return if target == self
      # raise ArgumentError, "target is self: #{target.inspect} == #{self.inspect}" if target == self
      raise ArgumentError, "invalid target: #{target}" unless target.is_a?(AbstractValue)
      @forward << target unless @forward.include?(target)
      @types.each do |type|
        add_type_to_abstract_value(type, target)
      end
    end

    def lookup_method(method_name)
      @types.each do |type|
        if type.is_a?(ClassType) && type.klass.is_a?(YARD::CodeObjects::ClassObject)
          type.klass.meths.each do |mth|
            if mth.name.to_s == method_name
              return mth
            end
          end
        end
      end
      nil
    end

    def type_string()
      @types.map(&:path).join(', ')
    end

    class << self
      def single_type(type)
        av = AbstractValue.new
        av.add_type(type)
        av.constant = true
        av
      end

      def single_type_nonconst(type)
        av = AbstractValue.new
        av.add_type(type)
        av
      end

      def nil_type
        single_type(InstanceType.new("::NilClass"))
      end
    end

    private

    def add_type_to_abstract_value(type, aval)
      raise ArgumentError, "target is constant: #{aval.inspect}" if aval.constant
      aval.add_type(type)
    end
  end
end
