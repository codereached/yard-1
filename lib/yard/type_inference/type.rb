module YARD::TypeInference
  class Type
    def initialize(*args)

    end
  end

  class ClassType < Type
    def initialize(klass)
      super
      @klass = klass
    end

    attr_reader :klass

    def path
      if klass.is_a?(CodeObjects::Base)
        klass.path
      else
        klass
      end
    end
  end

  class InstanceType < ClassType
    def path
      super + '#'
    end
  end

  class MethodType < Type
    def initialize(klass, method_scope)
      raise ArgumentError, "invalid klass: #{klass}" unless klass.is_a?(ClassType)
    end
  end
end
