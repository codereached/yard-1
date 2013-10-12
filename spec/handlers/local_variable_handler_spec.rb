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

  it "should parse local variables inside singleton classes" do
    # TODO!(sqs): give local vars in singleton classes a path denoting that they
    # are in the singleton class (since otherwise they could collide with local
    # vars defined in the non-singleton class)
    obj = Registry.at("A::B>somevar:6")
    obj.source.should == "somevar = \"in singleton class\""
    obj.rhs.source.should == '"in singleton class"'
  end

  it "should parse local variables inside methods" do
    obj = Registry.at("A::B#method>somevar:4")
    obj.source.should == "somevar = \"in method\""
    obj.rhs.source.should == '"in method"'
  end
end
