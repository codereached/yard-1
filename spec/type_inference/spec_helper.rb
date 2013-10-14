require File.join(File.dirname(__FILE__), "..", "spec_helper")

include TypeInference

def parse_file_and_infer_types(file, thisfile = __FILE__, log_level = log.level, ext = '.rb.txt')
  parser = parse_file(file, thisfile, log_level, ext)
  ti = Inferencer.new(Registry)
  ti.add_ast(parser.enumerator)
  ti.infer_types!
  ti
end

def check_file_inline_type_annotations(file, thisfile = __FILE__, log_level = log.level, ext = '.rb.txt')
  Registry.clear
  path = File.join(File.dirname(thisfile), 'examples', file.to_s + ext)
  parser = YARD::Parser::SourceParser
  parser.after_parse_file do |parser|
    describe "inline annotations in #{file}" do
      lines = File.readlines(parser.file)
      each_comment_with_prefix(": ", lines) do |line, type_string, lineno|
        enum = parser.instance_variable_get("@parser").enumerator
        enum.each do |topnode|
          topnode.traverse do |node|
            if node.line_range.last == lineno
              it "should infer type of #{node.inspect} as #{type_string}" do
                av = Registry.abstract_value(node)
                av.type_string.should == type_string
              end
              break
            end
          end
        end
      end
    end
  end

  parser.parse(path, [], log_level)
end

def each_comment_with_prefix(prefix, file_lines)
  file_lines.each_with_index do |line, i|
    if line =~ /^.*#\s*#{Regexp.quote(prefix)}\s*(.*)$/
      yield file_lines[i], $1, i+1
    end
  end
end
