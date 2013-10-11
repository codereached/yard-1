# Handles references
module YARD::Handlers::Ruby::ReferenceHandlers
  class VarRefHandler < YARD::Handlers::Ruby::Base
    handles :var_ref

    process do
      name_node = statement[0]
      name = name_node[0]
      target = YARD::Registry.resolve(namespace, name)
      if target
        add_reference Reference.new(target, statement)
      end
    end
  end

  class TopConstRefHandler < YARD::Handlers::Ruby::Base
    handles :top_const_ref

    process do
      name_node = statement[0]
      name = name_node[0]
      target = YARD::Registry.resolve(namespace, NSEP+name)
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

  class CallRefHandler < YARD::Handlers::Ruby::Base
    handles :call

    process do
      recv = statement[0]
      parse_block(recv)

      recv_object = YARD::Registry.resolve(namespace, recv.path.join(NSEP))
      if recv_object && recv_object.is_a?(NamespaceObject)
        method_name = statement.method_name(true)
        method_name = statement[1] == "." ? "##{method_name}" : method_name
        target = YARD::Registry.resolve(recv_object, method_name, true, true)
        if target
          add_reference Reference.new(target, statement.method_name)
        end
      end
    end
  end

  # NodeTraverser traverses through AST nodes that do not affect the namespace.
  class NodeTraverser < YARD::Handlers::Ruby::Base
    handles :command

    process do
      statement.each do |st|
        parse_block(st)
      end
    end
  end
end
