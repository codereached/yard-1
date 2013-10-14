require File.dirname(__FILE__) + '/spec_helper'

describe "YARD::Handlers::Ruby::TypeInference" do
  describe "basic type inference" do
    before(:all) { parse_file :type_inference_001_basic, __FILE__ }

    {
      "Myarrayclass" => "Array",
      "Mystringclass" => "String",
      "Mystring" => "String#",
      "Myfixnum" => "Fixnum#",
      "Mybool" => "Boolean#",
      "Myhash" => "Hash#",
      "Myarray" => "Array#",
      "A" => "A",
      "A::B" => "A::B",
      "C" => "C",
      "C::D" => "C::D",
      "file:spec/handlers/examples/type_inference_001_basic.rb.txt_local_0>mylocalvar" => "String#",
    }.each do |path, typename|
      it "should infer #{typename} type of #{path.inspect}" do
        Registry.at(path).itype.should == typename
      end
    end
  end
end
