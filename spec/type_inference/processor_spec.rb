require File.dirname(__FILE__) + '/spec_helper'

describe "YARD::TypeInference::Processor" do
  describe "simple" do
    check_file_inline_type_annotations(:inferencer_001_simple, __FILE__)
  end
end
