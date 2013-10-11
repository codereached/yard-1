require 'json'

module YARD
  module Serializers
    class JSONSerializer < Base
      def before_serialize
        print("[\n")
      end

      def serialize(object)
        return unless output?(object)
        if @i
          print(",\n")
        else
          @i = true
        end
        print(JSON.fast_generate(prepare(object)))
      end

      def after_serialize
        print("\n]\n")
      end

      def output?(object)
        object.parent_module && object.ast_node
      end

      def prepare(object)
        o = {
          :name => object.name,
          :path => object.path,
          :module => object.parent_module,
          :type => object.type,
          :file => object.file,
          :def_start => object.ast_node.source_range.first,
          :def_end => object.ast_node.source_range.last,
        }

        if !object.docstring.empty?
          o[:docstring] = object.format(:format => :html, :markup => :asciidoc, :template => :sourcegraph)
        end

        case object.type
        when :method
          o[:method_data] = {:signature => object.signature.sub('def ', '')}
        end
        o
      end
    end
  end
end
