require File.dirname(__FILE__) + '/spec_helper'

describe "YARD::TypeInference::Processor" do
  describe "simple" do
    check_file_inline_type_annotations(:inferencer_001_simple, __FILE__)
  end

  describe "method calls" do
    check_file_inline_type_annotations(:inferencer_002_calls, __FILE__)
  end

  describe "instantiation" do
    check_file_inline_type_annotations(:inferencer_003_instantiation, __FILE__)
  end

  describe "circular" do
    check_file_inline_type_annotations(:inferencer_004_circular, __FILE__)
  end

  describe "method with args" do
    check_file_inline_type_annotations(:inferencer_005_method_args, __FILE__)
  end

  describe "instance method with args" do
    check_file_inline_type_annotations(:inferencer_006_imethod_args, __FILE__)
  end
end
