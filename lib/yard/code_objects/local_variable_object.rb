module YARD::CodeObjects
  # Represents a local variable inside a scope. The path is expressed
  # in the form TODO!(sqs)
  class LocalVariableObject < Base
    # Creates a new local variable object in +namespace+ with +name+, in the
    # scope of +owner+.
    #
    # @see Base.new
    def initialize(namespace, name, owner, ast_node, *args, &block)
      self.owner = owner
      self.ast_node = ast_node
      super(namespace, name, *args, &block)
    end

    # @return [String] the local variable's assigned value
    attr_accessor :rhs

    # @return [CodeObjects::Base] the object that creates this local variable's
    # enclosing scope
    attr_accessor :owner

    # override to include "owner" in path string
    def path
      "#{owner.root? ? '' : owner.path}>#{name}:#{owner.next_scope_entry_id}"
    end
  end
end
