require File.dirname(__FILE__) + '/../helper'

class Sinatra::EventContext # :nodoc:

  def render_foo(template)
    require 'erb'
    ERB.new(template).result(binding)
  end
  
end

describe "Renderer" do

  before(:each) do
    Layouts.clear
    @context = Sinatra::EventContext.new(stub())
  end

  it "should render render a tempalate" do
    @context.render('foo', :foo).should.equal 'foo'
  end
  
  it "should render with a layout if given" do
    result = @context.render('content', :foo) do
      'X <%= yield %> X'
    end
    
    result.should.equal 'X content X'
  end
  
  it "should render default layout if it exists and layout if no layout name given" do
    Layouts[:layout] = 'X <%= yield %> Y'
    @context.render('foo', :foo).should.equal 'X foo Y'
    
    Layouts[:foo] = 'Foo <%= yield %> Layout'
    @context.render('bar', :foo, :layout => :foo).should.equal 'Foo bar Layout'
  end
  
  it "should read template from a file if exists" do
    File.expects(:read).with('views/bar.foo').returns('foo content')
    @context.render(:bar, :foo).should.equal 'foo content'
    
    File.expects(:read).with('views2/bar.foo').returns('foo content')
    @context.render(:bar, :foo, :views_directory => 'views2').should.equal 'foo content'
  end
    
end
