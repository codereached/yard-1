require 'json'

module YARD
  module Serializers
    class JSONSerializer < Base
      def serialize(data)
        data = {
          :objects => data[:objects].select { |o| output_object?(o) }.map { |o| prepare_object(o) },
          :references => (data[:references] || {}).values.flatten.select { |r| output_reference?(r) }.map { |r| prepare_reference(r) },
        }
        print(JSON.fast_generate(data))
      end

      def after_serialize
        print("\n")
      end

      def output_object?(object)
        object.parent_module && object.ast_node
      end

      def prepare_object(object)
        o = {
          :name => object.name,
          :path => object.path,
          :module => object.parent_module,
          :type => object.type,
          :file => object.file,
          :def_start => object.ast_node.source_range.first,
          :def_end => object.ast_node.source_range.last + 1,
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

      def output_reference?(ref)
        true
      end

      def prepare_reference(ref)
        r = {
          :target => ref.target,
          :file => ref.ast_node.file,
          :start => ref.ast_node.source_range.first,
          :end => ref.ast_node.source_range.last + 1,
        }
        r
      end
    end
  end
end
