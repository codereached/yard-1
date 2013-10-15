module YARD::TypeInference
  class Processor
    def initialize
      @started = {}
      @memo = {}
    end

    def process_ast_list(ast)
      ast.map do |ast_node|
        process_ast_node(ast_node)
      end.last
    end

    alias process_list process_ast_list

    def process_ast_node(ast_node)
      raise ArgumentError, "invalid ast node: #{ast_node}" unless ast_node.is_a?(YARD::Parser::Ruby::AstNode)

      method_name = "process_#{ast_node.type}"
      if not respond_to?(method_name)
        raise ArgumentError, "no #{method_name} processor method"
      end

      # handle circular refs
      if @started[ast_node] && !@memo.include?(ast_node)
        return YARD::Registry.abstract_value_for_ast_node(ast_node, false)
      end

      if @memo.include?(ast_node)
        return @memo[ast_node]
      end

      @started[ast_node] = true
      @memo[ast_node] = send(method_name, ast_node)
    end

    def process_assign(ast_node)
      lhs = ast_node[0]
      rhs = ast_node[1]
      rhs_av = process_ast_node(rhs)
      lhs_av = YARD::Registry.abstract_value(lhs)
      rhs_av.propagate(lhs_av)
      av = YARD::Registry.abstract_value_for_ast_node(ast_node, false)
      lhs_av.propagate(av)
      av
    end

    def process_class(ast_node)
      bodystmt = ast_node[2]
      process_ast_node(bodystmt)
      nil
    end

    def process_module(ast_node)
      bodystmt = ast_node[1]
      process_ast_node(bodystmt)
      nil
    end

    def process_def(ast_node)
      method_obj = YARD::Registry.get_object_for_ast_node(ast_node)
      method_type = Type.from_object(method_obj)

      body_av = process_ast_node(ast_node[2]) # def body
      body_av.propagate(method_type.return_type)
      AbstractValue.single_type_nonconst(method_type)
    end

    def process_defs(ast_node)
      method_obj = YARD::Registry.get_object_for_ast_node(ast_node)
      method_type = Type.from_object(method_obj)

      body_av = process_ast_node(ast_node[4]) # def body
      body_av.propagate(method_type.return_type)
      AbstractValue.single_type_nonconst(method_type)
    end

    def process_const_path_ref(ast_node)
      ast_node.map do |n|
        process_ast_node(n)
      end.last
    end

    def process_ident(ast_node)
      av = YARD::Registry.abstract_value(ast_node)
      obj = YARD::Registry.get_object_for_ast_node(ast_node)
      if obj.is_a?(YARD::CodeObjects::MethodObject)
        method_av = process_ast_node(obj.ast_node)
        method_av.propagate(av)
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
     YARD::Registry.abstract_value(ast_node)
    end

    def process_cvar(ast_node)
     YARD::Registry.abstract_value(ast_node)
    end

    def process_kw(ast_node)
     YARD::Registry.abstract_value(ast_node)
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
      av = YARD::Registry.abstract_value_for_ast_node(ast_node, false)
      ref_av.propagate(av)
      av
    end

    def process_const(ast_node)
      av = YARD::Registry.abstract_value(ast_node)
      av.constant = true
      obj = YARD::Registry.get_object_for_ast_node(ast_node)
      if obj && obj.is_a?(YARD::CodeObjects::ClassObject)
        av.add_type(Type.from_object(obj))
      end
      av
    end

    def process_fcall(ast_node)
      av = YARD::Registry.abstract_value_for_ast_node(ast_node, false)

      method_av = process_ast_node(ast_node[0])
      method_av.types.each do |mtype|
        mtype.return_type.propagate(av)
      end

      av
    end

    def process_call(ast_node)
      av = YARD::Registry.abstract_value_for_ast_node(ast_node, false)
      recv_av = process_ast_node(ast_node[0])

      method_av = process_ast_node(ast_node[2])
      method_obj = YARD::Registry.get_object_for_ast_node(ast_node[2])
      if method_obj && method_obj.name == :new && !method_obj.namespace.root?
        mtype = MethodType.new(method_obj.namespace, :class, :new, method_obj)
        mtype.return_type.add_type(InstanceType.new(method_obj.namespace))
        method_av.add_type(mtype)

        # if klass.new doesn't exist but klass#initialize does, then update ref
        # that we emitted in reference_handlers.rb to point to klass#initialize.
        if method_obj.is_a?(YARD::CodeObjects::Proxy)
          initialize_method = YARD::Registry.resolve(method_obj.namespace, "#initialize", true)
          if initialize_method.is_a?(YARD::CodeObjects::MethodObject)
            YARD::Registry.delete_reference(YARD::CodeObjects::Reference.new(method_obj, ast_node[2], false))
            YARD::CodeObjects::Reference.new(initialize_method, ast_node[2])
          end
        end
      else
        # couldn't determine method, use inferred types
        method_name = ast_node[2].source
        method_obj = recv_av.lookup_method(method_name)
        if method_obj
          mtype = Type.from_object(method_obj)
          method_av = process_ast_node(method_obj.ast_node)

          # attr_writer we've found a new reference thanks to type inference, so add it to Registry.references
          # TODO(sqs): add a spec that tests that we add it to Registry.references
          YARD::Registry.add_reference(YARD::CodeObjects::Reference.new(method_obj, ast_node[2]))
        else
          log.warn "Couldn't find method_obj for method #{method_name.inspect} in recv #{ast_node[0].inspect}"
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
      av = YARD::Registry.abstract_value_for_ast_node(ast_node, false)

      method_av = process_ast_node(ast_node[0])
      method_av.types.each do |mtype|
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