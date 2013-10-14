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
  before(:all) { Registry.clear }
  path = File.join(File.dirname(thisfile), 'examples', file.to_s + ext)
  parser = YARD::Parser::SourceParser
  describe "inline annotations in #{path}" do
    lines = File.readlines(path)
    p = YARD::Parser::Ruby::RipperParser.new(File.read(path), path)
    p.parse
    each_comment_with_prefix(": ", lines) do |line, type_string, lineno|
      enum = p.enumerator
      enum.each do |topnode|
        topnode.traverse do |node|
          if node.line_range.last == lineno
            it "should infer type of #{node.inspect} (line #{node.line_range}) as #{type_string}" do
              av = Registry.abstract_value(node)
              av.type_string.should == type_string
            end
            break
          end
        end
      end
    end
  end

  before(:all) { parser.parse(path, [], log_level) }
end

def each_comment_with_prefix(prefix, file_lines)
  file_lines.each_with_index do |line, i|
    if line =~ /^.*#\s*#{Regexp.quote(prefix)}\s*(.*)$/
      yield file_lines[i], $1, i+1
    end
  end
end
