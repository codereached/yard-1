# Handles a local variable
class YARD::Handlers::Ruby::LocalVariableHandler < YARD::Handlers::Ruby::Base
  handles :assign

  process do
    if statement[0].type == :var_field && statement[0][0].type == :ident
      name = statement[0][0][0]
      rhs = statement[1]
      register LocalVariableObject.new(namespace, name, owner, statement) do |o|
        o.source = statement
        o.rhs = rhs
        o.owner = owner
      end
    end
  end
end
