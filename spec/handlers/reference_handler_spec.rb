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

    it "should get 5 references to C1" do
      Registry.references_to("C1").length.should == 5
    end

    it "should get 3 references to C1.my_class_method" do
      Registry.references_to("C1.my_class_method").length.should == 3
    end
  end
end
