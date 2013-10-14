# Handles a instance variable (@@variable)
class YARD::Handlers::Ruby::InstanceVariableHandler < YARD::Handlers::Ruby::Base
  handles :assign

  process do
    if statement[0].type == :var_field && statement[0][0].type == :ivar
      name = statement[0][0][0]
      value = statement[1].source
      register InstanceVariableObject.new(namespace, name) do |o|
        o.source = statement
        o.value = value
      end
    end
  end
end
