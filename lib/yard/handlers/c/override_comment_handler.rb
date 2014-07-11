# Parses comments
class YARD::Handlers::C::OverrideCommentHandler < YARD::Handlers::C::Base
  handles %r{.}
  statement_class Comment

  process do
    return if statement.overrides.empty?
    statement.overrides.each do |type, name|
      override_comments << [name, statement]
      obj = nil
      case type
      when :class
        name, superclass = *name.split(/\s*<\s*/)
        obj = YARD::CodeObjects::ClassObject.new(:root, name)
        obj.superclass = "::#{superclass}" if superclass
      when :module
        obj = YARD::CodeObjects::ModuleObject.new(:root, name)
      end

      # Guess the character range of this comment's definition so we can emit it
      # as a ref later. For Ruby defs, we get refs by walking the AST and
      # performing type inference, but it's much simpler to just emit this ref
      # here (because we don't have a C AST, C type inference, etc.).
      if obj
        # Fall back to a fake name range, just so we can guarantee that every
        # defn has a name range. The `|| N` accomplishes this. Note that the
        # "Document-(class|module|method|const): NAME" is stripped from the
        # comment, but if we chose N == 23, then we highlight the name most of
        # the time. TODO(sqs): this is very hacky and imperfect; it doesn't
        # always highlight the name.
        name_start = (statement.source.index(name) || 23) + statement.source_range.first
        obj.name_range = (name_start..name_start + name.length)
      end

      register(obj)
    end
  end

  def register_docstring(object, docstring = statement.source, stmt = statement)
    super
  end

  def register_file_info(object, file = parser.file, line = statement.line, comments = statement.comments)
    super
  end
end
