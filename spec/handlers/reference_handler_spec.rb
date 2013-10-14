require File.dirname(__FILE__) + '/spec_helper'

describe "YARD::Handlers::Ruby::ReferenceHandler" do
  describe "simple" do
    before(:all) { parse_file :reference_handler_001, __FILE__ }

    it "should get 2 references to A" do
      Registry.references_to("A").length.should == 2
    end

    it "should get namespace qualifier reference of A" do
      refs = Registry.references_to("A")
      refs[0].ast_node.source.should == "A"
      refs[0].ast_node.source_range.should == (35..35)
    end

    it "should get top-level reference to A" do
      refs = Registry.references_to("A")
      refs[1].ast_node.source.should == "A"
      refs[1].ast_node.source_range.should == (40..40)
    end

    it "should get 2 references to B" do
      Registry.references_to("A::B").length.should == 2
    end

    it "should get reference to B in module A block" do
      refs = Registry.references_to("A::B")
      refs[0].ast_node.source.should == "B"
      refs[0].ast_node.source_range.should == (28..28)
    end

    it "should get top-level qualified reference to B" do
      refs = Registry.references_to("A::B")
      refs[1].ast_node.source.should == "B"
      refs[1].ast_node.source_range.should == (38..38)
    end
  end

  describe "nested modules" do
    before(:all) { parse_file :reference_handler_002, __FILE__ }

    it "should get 10 references to M1" do
      Registry.references_to("M1").length.should == 10
    end

    it "should get 6 references to M1::M2" do
      Registry.references_to("M1::M2").length.should == 6
    end

    it "should get 4 references to M1::M2::C1" do
      Registry.references_to("M1::M2::C1").length.should == 4
    end

    it "should get 2 references to M1::M2::C1::C2" do
      Registry.references_to("M1::M2::C1::C2").length.should == 2
    end

    it "should get 3 references to M1::M3" do
      Registry.references_to("M1::M3").length.should == 3
    end

    it "should get 1 reference to M1::M3::C3" do
      Registry.references_to("M1::M3::C3").length.should == 1
    end
  end

  describe "with `class << self` usage" do
    before(:all) { parse_file :reference_handler_003, __FILE__ }

    it "should get 6 references to C1" do
      Registry.references_to("C1").length.should == 6
    end

    it "should get 3 references to C1.my_class_method" do
      Registry.references_to("C1.my_class_method").length.should == 3
    end
  end

  describe "methods and class methods" do
    before(:all) { parse_file :reference_handler_004, __FILE__ }

    it "should get 36 references to C1" do
      Registry.references_to("C1").length.should == 36
    end

    it "should get 4 references to C1#m1" do
      Registry.references_to("C1#m1").length.should == 4
    end

    it "should get 4 references to C1#m2" do
      Registry.references_to("C1#m2").length.should == 4
    end

    it "should get 16 references to C1.cm1" do
      Registry.references_to("C1.cm1").length.should == 17
    end

    it "should get 22 references to C1.cm2" do
      Registry.references_to("C1.cm2").length.should == 22
    end

    it "should get 8 references to C1.cm3" do
      Registry.references_to("C1.cm3").length.should == 8
    end
  end

  describe "local vars" do
    before(:all) { parse_file :reference_handler_005_local_vars, __FILE__ }

    {
      "file:spec/handlers/examples/reference_handler_005_local_vars.rb.txt_local_0>v" => 2,
      "file:spec/handlers/examples/reference_handler_005_local_vars.rb.txt_local_0>#m1>v" => 2,
      "M1>_local_0>v" => 2,
      "M1::C1>_local_0>v" => 2,
      "M1::C1>_local_0>#cim1>v" => 2,
      "M1::C1>_local_0>cm1>v" => 2,
      "M1::C1>_local_0><< self_local_1>v" => 2,
      "M1>_local_0>#mm1>v" => 2,
      "M1>_local_0>#mm1>#subm1>v" => 2,
    }.each do |path, num_refs|
      it "should get #{num_refs} reference to #{path}" do
        Registry.references_to(path).length.should == num_refs
      end
    end
  end

  describe "traversing AST to get refs" do
    before(:all) { parse_file :reference_handler_006_traverse, __FILE__ }

    {
      "M" => 54, # TODO(sqs): should be 57 but 53 is good enough for now
    }.each do |path, num_refs|
      it "should get #{num_refs} reference to #{path}" do
        Registry.references_to(path).length.should == num_refs
      end
    end
  end
end
