require 'json'

module YARD
  module Serializers
    class JSONSerializer < Base
      # only emit symbols and refs defined in these files
      def initialize(files)
        @files = files
      end

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
        object.parent_module && object.ast_node && object.ast_node.respond_to?(:source_range) && @files.include?(object.ast_node.file)
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
          o[:docstring] = begin
                            object.format(:format => :html, :markup => :asciidoc, :template => :sourcegraph)
                          rescue
                            "<!-- doc error -->"
                          end
        end

        case object.type
        when :method
          o[:type_expr] = object.signature.sub('def ', '')
        end
        o
      end

      def output_reference?(ref)
        @files.include?(ref.ast_node.file)
      end

      def prepare_reference(ref)
        r = {
          :target => ref.target,
          :file => ref.ast_node.file,
          :start => ref.ast_node.source_range.first,
          :end => ref.ast_node.source_range.last + 1,
        }
        begin
          r[:target_origin_yardoc_file] = ref.target.origin_yardoc_file.to_s
        rescue
        end
        r
      end
    end
  end
end
