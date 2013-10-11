module YARD::CodeObjects
  class Reference
    def initialize(target, ast_node)
      raise ArgumentError, "invalid target type" unless target.is_a?(Base)
      raise ArgumentError, "invalid AST node type" unless ast_node.is_a?(YARD::Parser::Ruby::AstNode)

      @target = target
      @ast_node = ast_node

      YARD::Registry.add_reference(self)
    end

    # @return [CodeObjects::Base] the object that this reference points to
    attr_reader :target

    # @return [Parser::Ruby::AstNode] the AST node of the reference expression
    attr_reader :ast_node
  end
end
