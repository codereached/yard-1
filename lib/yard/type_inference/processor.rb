module YARD::TypeInference
  class Processor
    def process_ast_list(ast)
      ast.map do |ast_node|
        process_ast_node(ast_node)
      end.last
    end

    alias process_list process_ast_list

    def process_ast_node(ast_node)
      raise ArgumentError, "invalid ast node: #{ast_node}" unless ast_node.is_a?(YARD::Parser::Ruby::AstNode)
      method_name = "process_#{ast_node.type}"
      if respond_to?(method_name)
        send(method_name, ast_node)
      else
        raise ArgumentError, "no #{method_name} processor method"
      end
    end

    def process_assign(ast_node)
      lhs = ast_node[0]
      rhs = ast_node[1]
      rhs_av = process_ast_node(rhs)
      lhs_av = Registry.abstract_value(lhs)
      rhs_av.propagate(lhs_av)
      av = Registry.abstract_value_for_ast_node(ast_node, false)
      lhs_av.propagate(av)
      av
    end

    def process_class(ast_node)
      bodystmt = ast_node[2]
      process_ast_node(bodystmt)
      nil
    end

    def process_def(ast_node)
      method_obj = Registry.get_object_for_ast_node(ast_node)
      method_type = Type.from_object(method_obj)

      body_av = process_ast_node(ast_node[2]) # def body
      body_av.propagate(method_type.return_type)
      AbstractValue.single_type_nonconst(method_type)
    end

    def process_defs(ast_node)
      method_obj = Registry.get_object_for_ast_node(ast_node)
      method_type = Type.from_object(method_obj)

      body_av = process_ast_node(ast_node[4]) # def body
      body_av.propagate(method_type.return_type)
      AbstractValue.single_type_nonconst(method_type)
    end

    def process_ident(ast_node)
      av = Registry.abstract_value(ast_node)
      obj = Registry.get_object_for_ast_node(ast_node)
      if obj.is_a?(CodeObjects::MethodObject)
        method_av = process_ast_node(obj.ast_node)
        puts "WARN: no types for method_av for #{ast_node.inspect}" if method_av.types.empty?
        method_av.propagate(av)
      else
        puts "WARN: no obj for AST ident #{ast_node.inspect}"
      end
      av
    end

    def process_int(ast_node)
      AbstractValue.single_type(InstanceType.new("::Fixnum"))
    end

    def process_string_literal(ast_node)
      AbstractValue.single_type(InstanceType.new("::String"))
    end

    def process_ivar(ast_node)
      # TODO
    end

    def process_kw(ast_node)
      Registry.abstract_value(ast_node)
    end

    def process_var_ref(ast_node)
      v = ast_node[0]
      ref_av = case v.type
               when :kw
                 if v[0] == "true"
                   AbstractValue.single_type(InstanceType.new("::TrueClass"))
                 elsif v[0] == "false"
                   AbstractValue.single_type(InstanceType.new("::FalseClass"))
                 elsif v[0] == "self"
                   process_ast_node(v) or raise "no obj for #{ast_node[0].source}"
                 else
                   raise "unknown keyword: #{v.source}"
                 end
               else
                 process_ast_node(v) or raise "no obj for #{ast_node[0].source}"
               end
      av = Registry.abstract_value_for_ast_node(ast_node, false)
      ref_av.propagate(av)
      av
    end

    def process_const(ast_node)
      av = Registry.abstract_value(ast_node)
      av.constant = true
      obj = Registry.get_object_for_ast_node(ast_node)
      if obj && obj.is_a?(CodeObjects::ClassObject)
        av.add_type(Type.from_object(obj))
      end
      av
    end

    def process_fcall(ast_node)
      method_av = Registry.abstract_value(ast_node[0])
      av = Registry.abstract_value(ast_node)
      method_av.types.each do |t|
        t.return_type.propagate(av)
      end
      av
    end

    def process_call(ast_node)
      av = Registry.abstract_value_for_ast_node(ast_node, false)
      recv_av = process_ast_node(ast_node[0])

      method_av = process_ast_node(ast_node[2])
      method_obj = Registry.get_object_for_ast_node(ast_node[2])
      if method_obj && method_obj.name == :new && !method_obj.namespace.root?
        mtype = MethodType.new(method_obj.namespace, :class, :new, method_obj)
        mtype.return_type.add_type(InstanceType.new(method_obj.namespace))
        method_av.add_type(mtype)
      else
        # couldn't determine method, use inferred types
        method_name = ast_node[2].source
        method_obj = recv_av.lookup_method(method_name)
        if method_obj
          mtype = Type.from_object(method_obj)
          method_av = process_ast_node(method_obj.ast_node)
        end
      end

      if method_av
        method_av.types.each do |t|
          t.return_type.propagate(av) if t.is_a?(MethodType) && t.return_type
          t.check! if t.is_a?(MethodType)
        end
      end

      av
    end


    def process_vcall(ast_node)
      av = Registry.abstract_value_for_ast_node(ast_node, false)

      method_av = process_ast_node(ast_node[0])
      method_av.types.each do |mtype|
        puts "#{mtype.return_type.type_string} PROPAGATE `#{av.type_string}`"
        mtype.return_type.propagate(av)
      end

      av
    end

    def process_void_stmt(_); AbstractValue.nil_type end

    def process_comment(_); nil end

    def process_registry
      # TODO
    end
  end
end
