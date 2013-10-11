require File.dirname(__FILE__) + '/spec_helper'

describe "YARD::Handlers::Ruby::LocalVariableHandler" do
  before(:all) { parse_file :local_variable_handler_001, __FILE__ }

  it "should parse local variables at the top level" do
    obj = Registry.at(">somevar:1")
    obj.source.should == "somevar = \"top level\""
    obj.rhs.source.should == '"top level"'
  end

  it "should parse local variables inside modules" do
    obj = Registry.at("A>somevar:1")
    obj.source.should == "somevar = \"in module\""
    obj.rhs.source.should == '"in module"'
  end

  it "should parse local variables inside classes" do
    obj = Registry.at("A::B>somevar:1")
    obj.source.should == "somevar = \"in class\""
    obj.rhs.source.should == '"in class"'
  end

  it "should parse local variables inside methods" do
    obj = Registry.at("A::B#method>somevar:3")
    obj.source.should == "somevar = \"in method\""
    obj.rhs.source.should == '"in method"'
  end
end
