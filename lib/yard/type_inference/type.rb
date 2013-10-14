module YARD::TypeInference
  class Type
    def initialize(*args)

    end

    def path
      raise NotImplementedError
    end

    def ==(o)
      o.is_a?(Type) && o.path == self.path
    end

    class << self
      def from_object(obj)
        if obj.is_a?(CodeObjects::ClassObject)
          ClassType.new(obj)
        elsif obj.is_a?(CodeObjects::MethodObject)
          MethodType.new(obj.namespace, obj.scope, obj.name, obj)
        else
          raise ArgumentError, "invalid obj: #{obj.inspect} (#{obj.type})"
        end
      end
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
    def initialize(namespace, method_scope, method_name, method_obj)
      raise ArgumentError, "invalid namespace: #{namespace}" if namespace && !namespace.is_a?(CodeObjects::NamespaceObject)
      @namespace = namespace
      @method_scope = method_scope
      @method_name = method_name
      @method_obj = method_obj
    end

    attr_reader :namespace
    attr_reader :method_scope
    attr_reader :method_name
    attr_reader :method_obj

    attr_accessor :return_type

    def path
      method_obj
    end
  end
end
