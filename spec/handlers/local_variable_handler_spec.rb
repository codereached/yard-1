require File.dirname(__FILE__) + '/spec_helper'

describe "YARD::Handlers::Ruby::LocalVariableHandler" do
  before(:all) {
    YARD::Handlers::Processor.process_references = true
    parse_file :local_variable_handler_001, __FILE__
  }
  after(:all) { YARD::Handlers::Processor.process_references = false }

  it "should parse local variables at the top level" do
    obj = Registry.at("file:spec/handlers/examples/local_variable_handler_001.rb.txt_local_0>somevar")
    obj.source.should == "somevar = \"top level\""
    obj.rhs.source.should == '"top level"'
  end

  it "should parse local variables inside modules" do
    obj = Registry.at("A>_local_0>somevar")
    obj.source.should == "somevar = \"in module\""
    obj.rhs.source.should == '"in module"'
  end

  it "should parse local variables inside classes" do
    obj = Registry.at("A::B>_local_0>somevar")
    obj.source.should == "somevar = \"in class\""
    obj.rhs.source.should == '"in class"'
  end

  it "should parse local variables inside singleton classes" do
    obj = Registry.at("A::B>_local_0><< self_local_0>somevar")
    obj.source.should == "somevar = \"in singleton class\""
    obj.rhs.source.should == '"in singleton class"'
  end

  it "should parse local variables inside methods" do
    obj = Registry.at("A::B>_local_0>#method>somevar")
    obj.source.should == "somevar = \"in method\""
    obj.rhs.source.should == '"in method"'
  end
end
