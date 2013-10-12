# Handles references
module YARD::Handlers::Ruby::ReferenceHandlers
  class VarRefHandler < YARD::Handlers::Ruby::Base
    handles :var_ref

    process do
      name_node = statement[0]
      name = name_node[0]

      target = if name_node.type == :kw && name_node[0] == 'self'
        namespace
      else
        local_scope.resolve(name) || YARD::Registry.resolve(namespace, name, false, false)
      end

      if target
        add_reference Reference.new(target, name_node)
      end
    end
  end

  class TopConstRefHandler < YARD::Handlers::Ruby::Base
    handles :top_const_ref

    process do
      name_node = statement[0]
      name = name_node[0]
      target = YARD::Registry.resolve(namespace, NSEP+name, false, true)
      if target
        add_reference Reference.new(target, statement)
      end
    end
  end

  class ConstPathRefHandler < YARD::Handlers::Ruby::Base
    handles :const_path_ref

    process do
      qualifier = statement[0]
      name_node = statement[1]
      parse_block(qualifier)

      target = YARD::Registry.resolve(namespace, statement.path.join(NSEP))
      if target
        add_reference Reference.new(target, name_node)
      end
    end
  end

  class InheritsRefHandler < YARD::Handlers::Ruby::Base
    # matches classes that inherit from another class
    def self.handles?(node)
      node.type == :class && node[1] != nil
    end

    process do
      parse_block(statement[1])
    end
  end


  class MethodDefsRefHandler < YARD::Handlers::Ruby::Base
    handles :defs

    process do
      recv = statement[0]
      nobj = namespace

      if recv[0].type != :ident
        nobj = P(namespace, recv.source) if recv[0].type == :const
        add_reference Reference.new(nobj, recv)
      end
    end
  end

  class CallRefHandler < YARD::Handlers::Ruby::Base
    handles :call

    process do
      recv = statement[0]
      parse_block(recv)

      next unless recv.ref?

      if recv[0].type == :kw && recv[0][0] == "self"
        recv_object = namespace
        meth_type = self.self_binding
      elsif recv.respond_to?(:path)
        recv_object = YARD::Registry.resolve(namespace, recv.path.join(NSEP))
        meth_type = :class # no type inference yet, so can't get instance methods
      end
      if recv_object && recv_object.is_a?(NamespaceObject)
        method_name = statement.method_name(true)
        method_name = meth_type == :instance ? "##{method_name}" : ".#{method_name}"
        target = YARD::Registry.resolve(recv_object, method_name, true, true)
        add_reference Reference.new(target, statement.method_name)
      end
    end
  end

  class VFCallRefHandler < YARD::Handlers::Ruby::Base
    handles :vcall, :fcall

    process do
      parse_block(statement[1])

      name_node = statement[0]
      if name_node.type == :ident
        method_name = name_node[0]
        method_name = self_binding == :instance ? "##{method_name}" : ".#{method_name}"
        method_object = YARD::Registry.resolve(namespace, method_name, true, true)
        add_reference Reference.new(method_object, name_node)
      end
    end
  end

  # NodeTraverser traverses through AST nodes that do not affect the namespace.
  class NodeTraverser < YARD::Handlers::Ruby::Base
    def self.handles?(node)
      [:list, :params, :list, :command, :command_call, :method_add_arg, :args_add_block, :arg_paren, :paren, :next].include?(node.type) || node.type.to_s.end_with?('_mod', '_literal') || node.class == AstNode || node.class == KeywordNode || node.class == ConditionalNode || node.class == LoopNode || node.class == ParameterNode
    end

    process do
      statement.each do |st|
        parse_block(st) if st.respond_to?(:type)
      end
    end
  end
end
