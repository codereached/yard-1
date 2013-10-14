module YARD::TypeInference
  class Processor
    def process_ast_list(ast)
      ast.map do |ast_node|
        process_ast_node(ast_node)
      end
    end

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
      av = Registry.abstract_value(ast_node)
      lhs_av.propagate(av)
      av
    end

    def process_int(ast_node)
      AbstractValue.single_type(InstanceType.new("::Fixnum"))
    end

    def process_string_literal(ast_node)
      AbstractValue.single_type(InstanceType.new("::String"))
    end

    def process_var_ref(ast_node)
      v = ast_node[0]
      case v.type
      when :kw
        if v[0] == "true"
          AbstractValue.single_type(InstanceType.new("::TrueClass"))
        elsif v[0] == "false"
          AbstractValue.single_type(InstanceType.new("::FalseClass"))
        end
      else
        Registry.abstract_value(ast_node) or raise "no obj for #{ast_node[0].source}"
      end
    end

    def process_registry
      # TODO
    end
  end
end
