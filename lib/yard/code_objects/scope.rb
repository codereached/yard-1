module YARD::CodeObjects
  module MultipleLocalScopes
    attr_reader :local_scopes

    def new_local_scope(name = "", parent = nil)
      name ||= ""
      @local_scopes ||= []
      name += "_local_#{@local_scopes.length}"
      ls = LocalScope.new(name, parent)
      @local_scopes << ls
      ls
    end
  end

  class LocalScope
    def initialize(name, parent = nil)
      raise ArgumentError, "Invalid parent_scope: #{parent}" if parent && !parent.is_a?(LocalScope) && !parent.is_a?(NamespaceObject)
      @name = name
      @parent = parent
      @children = []
    end

    def root?; false end
    def has_tag?(_); false end

    def path
      @path ||= if parent && !parent.root?
        [parent.path, name.to_s].join(sep)
      else
        name.to_s
      end
    end

    def sep; ">" end

    def name(prefix = false)
      prefix ? "#{sep}#{super}" : super
    end

    attr_reader :name
    attr_reader :parent
    attr_reader :children
  end
end
