require 'fileutils'
require 'digest/sha1'

module YARD
  # The +Registry+ is the centralized data store for all {CodeObjects} created
  # during parsing. The storage is a key value store with the object's path
  # (see {CodeObjects::Base#path}) as the key and the object itself as the value.
  # Object paths must be unique to be stored in the Registry. All lookups for
  # objects are done on the singleton Registry instance using the {Registry.at}
  # or {Registry.resolve} methods.
  #
  # == Saving / Loading a Registry
  # The registry is saved to a "yardoc file" (actually a directory), which can
  # be loaded back to perform any lookups. See {Registry.load!} and
  # {Registry.save} for information on saving and loading of a yardoc file.
  #
  # == Threading Notes
  # The registry class is a singleton class that is accessed directly in many
  # places across YARD. To mitigate threading issues, YARD (0.6.5+) makes
  # the Registry thread local. This means all access to a registry for a specific
  # object set must occur in the originating thread.
  #
  # @example Loading the Registry
  #   Registry.load!('/path/to/yardocfile') # loads all objects into memory
  #   Registry.at('YARD::CodeObjects::Base').docstring
  #   # => "+Base+ is the superclass of all code objects ..."
  # @example Getting an object by a specific path
  #   Registry.at('YARD::CodeObjects::Base#docstring')
  # @example Performing a lookup on a method anywhere in the inheritance tree
  #   Registry.resolve(P('YARD::CodeObjects::Base'), '#docstring', true)
  module Registry
    DEFAULT_YARDOC_FILE = ".yardoc"
    LOCAL_YARDOC_INDEX = File.expand_path('~/.yard/gem_index')
    DEFAULT_PO_DIR = "po"

    extend Enumerable

    class << self
      # @group Getting .yardoc File Locations

      # Returns the .yardoc file associated with a gem.
      #
      # @param [String] gem the name of the gem to search for
      # @param [String] ver_require an optional Gem version requirement
      # @param [Boolean] for_writing whether or not the method should search
      #   for writable locations
      # @return [String] if +for_writing+ is set to +true+, returns the best
      #   location suitable to write the .yardoc file. Otherwise, the first
      #   existing location associated with the gem's .yardoc file.
      # @return [nil] if +for_writing+ is set to false and no yardoc file
      #   is found, returns nil.
      def yardoc_file_for_gem(gem, ver_require = ">= 0", for_writing = false)
        spec = Gem.source_index.find_name(gem, ver_require)
        return if spec.empty?
        spec = spec.first

        if gem =~ /^yard-doc-/
          path = File.join(spec.full_gem_path, DEFAULT_YARDOC_FILE)
          return File.exist?(path) && !for_writing ? path : nil
        end

        if for_writing
          global_yardoc_file(spec, for_writing) ||
            local_yardoc_file(spec, for_writing)
        else
          local_yardoc_file(spec, for_writing) ||
            global_yardoc_file(spec, for_writing)
        end
      end

      # Gets/sets the yardoc filename
      # @return [String] the yardoc filename
      # @see DEFAULT_YARDOC_FILE
      attr_accessor :yardoc_file
      undef yardoc_file, yardoc_file=
      def yardoc_file=(v) Thread.current[:__yard_yardoc_file__] = v end
      def yardoc_file
        Thread.current[:__yard_yardoc_file__] ||= DEFAULT_YARDOC_FILE
      end

      # @group Loading Data from Disk

      # Loads the registry and/or parses a list of files
      #
      # @example Loads the yardoc file or parses files 'a', 'b' and 'c' (but not both)
      #   Registry.load(['a', 'b', 'c'])
      # @example Reparses files 'a' and 'b' regardless of whether yardoc file exists
      #   Registry.load(['a', 'b'], true)
      # @param [String, Array] files if +files+ is an Array, it should represent
      #   a list of files that YARD should parse into the registry. If reload is
      #   set to false and the yardoc file already exists, these files are skipped.
      #   If files is a String, it should represent the yardoc file to load
      #   into the registry.
      # @param [Boolean] reparse if reparse is false and a yardoc file already
      #   exists, any files passed in will be ignored.
      # @return [Registry] the registry object (for chaining)
      # @raise [ArgumentError] if files is not a String or Array
      def load(files = [], reparse = false)
        if files.is_a?(Array)
          if File.exist?(yardoc_file) && !reparse
            load_yardoc
          else
            size = thread_local_store.keys.size
            YARD.parse(files)
            save if thread_local_store.keys.size > size
          end
        elsif files.is_a?(String)
          load_yardoc(files)
        else
          raise ArgumentError, "Must take a list of files to parse or the .yardoc file to load."
        end
        self
      end

      # Loads a yardoc file directly
      #
      # @param [String] file the yardoc file to load.
      # @return [Registry] the registry object (for chaining)
      def load_yardoc(file = yardoc_file)
        clear
        thread_local_store.load(file)
        self
      end

      # Loads a yardoc file and forces all objects cached on disk into
      # memory. Equivalent to calling {load_yardoc} followed by {load_all}
      #
      # @param [String] file the yardoc file to load
      # @return [Registry] the registry object (for chaining)
      # @see #load_yardoc
      # @see #load_all
      # @since 0.5.1
      def load!(file = yardoc_file)
        clear
        thread_local_store.load!(file)
        self
      end

      # Forces all objects cached on disk into memory
      #
      # @example Loads all objects from disk
      #   Registry.load
      #   Registry.all.count #=> 0
      #   Registry.load_all
      #   Registry.all.count #=> 17
      # @return [Registry] the registry object (for chaining)
      # @since 0.5.1
      def load_all
        thread_local_store.load_all
        self
      end

      # @group Saving and Deleting Data from Disk

      # Saves the registry to +file+
      #
      # @param [String] file the yardoc file to save to
      # @return [Boolean] true if the file was saved
      def save(merge = false, file = yardoc_file)
        thread_local_store.save(merge, file)
      end

      # Deletes the yardoc file from disk
      # @return [void]
      def delete_from_disk
        thread_local_store.destroy
      end

      # @group Adding and Deleting Objects from the Registry

      # Registers a new object with the registry
      #
      # @param [CodeObjects::Base] object the object to register
      # @return [CodeObjects::Base] the registered object
      def register(object)
        return if object.is_a?(CodeObjects::Proxy)
        thread_local_store[object.path] = object
      end

      def add_reference(ref)
        @references ||= {}
        @ref_by_ast_node ||= {}
        @references[ref.target.path] ||= []
        if ensure_ref_unique(ref)
          @references[ref.target.path] << ref
        end
      end

      def delete_reference(ref)
        refs = @references[ref.target.path]
        return if !refs
        refs.delete(ref)
        @ref_by_ast_node.delete(_ast_key_with_type(ref.ast_node))
      end

      attr_reader :references

      def references_to(target)
        if target.is_a?(CodeObjects::Base)
          target = target.path
        end
        @references[target] || []
      end

      def _ast_key_with_type(astnode)
        "#{astnode.file}:#{astnode.type}:#{astnode.source_range}"
      end

      def _ast_key(astnode)
        "#{astnode.file}:#{astnode.source_range}"
      end

      def ensure_ref_unique(ref, should_raise=false)
        key = _ast_key_with_type(ref.ast_node)
        if @ref_by_ast_node[key]
            if should_raise
              raise "2 refs with same AST node: #{r.inspect} #{ref.inspect} (source range: #{r.ast_node.source_range} #{ref.ast_node.source_range})"
            end
          return false
        end
        @ref_by_ast_node[key] = ref
        @ref_by_ast_node[_ast_key(ref.ast_node)] = ref
        true
      end

      def get_object_for_ast_node(ast_node)
        ref = @ref_by_ast_node[_ast_key(ast_node)]
        if ref
          return ref.target
        end
        each do |o|
          next unless o.ast_node
          if o.ast_node.file == ast_node.file && o.ast_node.source_range == ast_node.source_range
            return o
          end
        end
        nil
      end

      def add_typed_expr(expr)
        raise ArgumentError, "invalid expr: #{expr}" unless expr.is_a?(YARD::TypeInference::Expr)
        @typed_exprs ||= []
        @typed_exprs << expr
        @typed_exprs_by_ast_node[_ast_key_with_type(expr.ast_node)] = expr if expr.is_a?(YARD::TypeInference::AnonymousExpr)
        @typed_exprs_by_object[expr.object.path] = expr if expr.is_a?(YARD::TypeInference::ObjectExpr)
      end

      def abstract_value_for_ast_node(ast_node, resolve = true)
        obj = get_object_for_ast_node(ast_node) if resolve
        if obj
          abstract_value_for_object(obj)
        else
          tx = @typed_exprs_by_ast_node[_ast_key_with_type(ast_node)]
          if !tx
            tx = YARD::TypeInference::AnonymousExpr.new(ast_node, nil)
            add_typed_expr(tx)
          end
          tx.abstract_value
        end
      end

      def abstract_value_for_object(object)
        tx = @typed_exprs_by_object[object.path]
        if !tx
          tx = YARD::TypeInference::ObjectExpr.new(object, nil)
          add_typed_expr(tx)
        end
        tx.abstract_value
      end

      def abstract_value(object_or_ast_node)
        if object_or_ast_node.is_a?(CodeObjects::Base)
          abstract_value_for_object(object_or_ast_node)
        elsif object_or_ast_node.is_a?(Parser::Ruby::AstNode)
          abstract_value_for_ast_node(object_or_ast_node)
        else
          raise ArgumentError, "invalid object or ast node: #{object_or_ast_node}"
        end
      end

      def add_ast(ast_nodes)
        @ast ||= []
        @ast += ast_nodes
      end

      attr_reader :ast

      # Deletes an object from the registry
      # @param [CodeObjects::Base] object the object to remove
      # @return [void]
      def delete(object)
        thread_local_store.delete(object.path)
      end

      # Clears the registry
      # @return [void]
      def clear
        @ast = []
        @references = {}
        @typed_exprs = []
        @typed_exprs_by_object = {}
        @typed_exprs_by_ast_node = {}
        self.thread_local_store = RegistryStore.new
      end

      # @group Accessing Objects in the Registry

      # Iterates over {all} with no arguments
      def each(&block)
        all.each(&block)
      end

      # Returns all objects in the registry that match one of the types provided
      # in the +types+ list (if +types+ is provided).
      #
      # @example Returns all objects
      #   Registry.all
      # @example Returns all classes and modules
      #   Registry.all(:class, :module)
      # @param [Array<Symbol>] types an optional list of types to narrow the
      #   objects down by. Equivalent to performing a select:
      #     +Registry.all.select {|o| types.include(o.type) }+
      # @return [Array<CodeObjects::Base>] the list of objects found
      # @see CodeObjects::Base#type
      def all(*types)
        if types.empty?
          thread_local_store.values.select {|obj| obj != root }
        else
          list = []
          types.each do |type|
            list += thread_local_store.values_for_type(type)
          end
          list
        end
      end

      # Returns the paths of all of the objects in the registry.
      # @param [Boolean] reload whether to load entire database
      # @return [Array<String>] all of the paths in the registry.
      def paths(reload = false)
        thread_local_store.keys(reload).map {|k| k.to_s }
      end

      # Returns the object at a specific path.
      # @param [String, :root] path the pathname to look for. If +path+ is +root+,
      #   returns the {root} object.
      # @return [CodeObjects::Base] the object at path
      # @return [nil] if no object is found
      def at(path) path ? thread_local_store[path] : nil end
      alias_method :[], :at

      # The root namespace object.
      # @return [CodeObjects::RootObject] the root object in the namespace
      def root; thread_local_store[:root] end

      # @param [String] name the locale name.
      # @return [I18n::Locale] the locale object for +name+.
      # @since 0.8.3
      def locale(name)
        thread_local_store.locale(name)
      end

      # Attempts to find an object by name starting at +namespace+, performing
      # a lookup similar to Ruby's method of resolving a constant in a namespace.
      #
      # @example Looks for instance method #reverse starting from A::B::C
      #   Registry.resolve(P("A::B::C"), "#reverse")
      # @example Looks for a constant in the root namespace
      #   Registry.resolve(nil, 'CONSTANT')
      # @example Looks for a class method respecting the inheritance tree
      #   Registry.resolve(myclass, 'mymethod', true)
      # @example Looks for a constant but returns a proxy if not found
      #   Registry.resolve(P('A::B::C'), 'D', false, true) # => #<yardoc proxy A::B::C::D>
      # @example Looks for a complex path from a namespace
      #   Registry.resolve(P('A::B'), 'B::D') # => #<yardoc class A::B::D>
      # @param [CodeObjects::NamespaceObject, nil] namespace the starting namespace
      #   (module or class). If +nil+ or +:root+, starts from the {root} object.
      # @param [String, Symbol] name the name (or complex path) to look for from
      #   +namespace+.
      # @param [Boolean] inheritance Follows inheritance chain (mixins, superclass)
      #   when performing name resolution if set to +true+.
      # @param [Boolean] proxy_fallback If +true+, returns a proxy representing
      #   the unresolved path (namespace + name) if no object is found.
      # @param [Symbol, nil] type the {CodeObjects::Base#type} that the resolved
      #   object must be equal to. No type checking if nil.
      # @return [CodeObjects::Base] the object if it is found
      # @return [CodeObjects::Proxy] a Proxy representing the object if
      #   +proxy_fallback+ is +true+.
      # @return [nil] if +proxy_fallback+ is +false+ and no object was found.
      # @see P
      def resolve(namespace, name, inheritance = false, proxy_fallback = false, type = nil)
        if namespace.is_a?(CodeObjects::Proxy)
          return proxy_fallback ? CodeObjects::Proxy.new(namespace, name, type) : nil
        end

        if namespace == :root || !namespace
          namespace = root
        else
          namespace = namespace.parent until namespace.is_a?(CodeObjects::NamespaceObject)
        end
        orignamespace = namespace

        name = name.to_s
        if name =~ /^#{CodeObjects::NSEPQ}/
          [name, name[2..-1]].each do |n|
            found = at(n)
            return found if found && (type.nil? || found.type == type)
          end
        else
          while namespace
            if namespace.is_a?(CodeObjects::NamespaceObject)
              if inheritance
                nss = namespace.inheritance_tree(true)
                if namespace.respond_to?(:superclass)
                  if namespace.superclass != P('BasicObject')
                    nss |= [P('Object')]
                  end
                  nss |= [P('BasicObject')]
                end
              else
                nss = [namespace]
              end
              nss.each do |ns|
                next if ns.is_a?(CodeObjects::Proxy)
                found = partial_resolve(ns, name, type)
                return found if found
              end
            end
            namespace = namespace.parent
          end
        end
        proxy_fallback ? CodeObjects::Proxy.new(orignamespace, name, type) : nil
      end

      # @group Managing Source File Checksums

      # @return [Hash{String => String}] a set of checksums for files
      def checksums
        thread_local_store.checksums
      end

      # @param [String] data data to checksum
      # @return [String] the SHA1 checksum for data
      def checksum_for(data)
        Digest::SHA1.hexdigest(data)
      end

      # @group Managing Internal State (Advanced / Testing Only)

      # Whether or not the Registry storage should load everything into a
      # single object database (for disk efficiency), or spread them out
      # (for load time efficiency).
      #
      # @note Setting this attribute to nil will offload the decision to
      #   the {RegistryStore storage adapter}.
      # @return [Boolean, nil] if this value is set to nil, the storage
      #   adapter will decide how to store the data.
      attr_accessor :single_object_db
      undef single_object_db, single_object_db=
      def single_object_db=(v) Thread.current[:__yard_single_db__] = v end
      def single_object_db; Thread.current[:__yard_single_db__] end

      # The assumed types of a list of paths. This method is used by CodeObjects::Base
      # @return [{String => Symbol}] a set of unresolved paths and their assumed type
      # @private
      # @deprecated The registry no longer globally tracks proxy types.
      def proxy_types
        thread_local_store.proxy_types
      end

      # @group I18n features

      # Gets/sets the directory that has LANG.po files
      # @return [String] the directory that has .po files
      attr_accessor :po_dir
      undef po_dir, po_dir=
      def po_dir=(dir) Thread.current[:__yard_po_dir__] = dir end
      def po_dir
        Thread.current[:__yard_po_dir__] ||= DEFAULT_PO_DIR
      end

      # @group Legacy Methods

      # The registry singleton instance.
      #
      # @deprecated use Registry.methodname directly.
      # @return [Registry] returns the registry instance
      def instance; self end

      private

      # @group Accessing Objects in the Registry

      # Attempts to resolve a name in a namespace
      #
      # @param [CodeObjects::NamespaceObject] namespace the starting namespace
      # @param [String] name the name to look for
      # @param [Symbol, nil] type the {CodeObjects::Base#type} that the resolved
      #   object must be equal to
      def partial_resolve(namespace, name, type = nil)
        obj = at(name) || at('#' + name) if namespace.root?
        return obj if obj && (type.nil? || obj.type == type)
        [CodeObjects::NSEP, CodeObjects::CSEP, ''].each do |s|
          next if s.empty? && name =~ /^\w/
          path = name
          if namespace != root
            path = [namespace.path, name].join(s)
          end
          found = at(path)
          return found if found && (type.nil? || found.type == type)
        end
        nil
      end

      # @group Retrieving yardoc File Locations

      def global_yardoc_file(spec, for_writing = false)
        path = spec.full_gem_path
        yfile = File.join(path, DEFAULT_YARDOC_FILE)
        if for_writing && File.writable?(path)
          return yfile
        elsif !for_writing && File.exist?(yfile)
          return yfile
        end
      end

      def local_yardoc_file(spec, for_writing = false)
        path = Registry::LOCAL_YARDOC_INDEX
        FileUtils.mkdir_p(path) if for_writing
        path = File.join(path, "#{spec.full_name}.yardoc")
        if for_writing
          path
        else
          File.exist?(path) ? path : nil
        end
      end

      # @group Threading support

      # @since 0.6.5
      def thread_local_store
        Thread.current[:__yard_registry__] ||= clear
      end

      # @since 0.6.5
      def thread_local_store=(value)
        Thread.current[:__yard_registry__] = value
      end
    end
  end
end
