require File.dirname(__FILE__) + '/../lib/sinatra'

require 'rubygems'
require 'test/spec'

context "Simple Events" do

  def simple_request_hash(method, path)
    {
      'REQUEST_METHOD' => method.to_s.upcase,
      'PATH_INFO' => path
    }
  end

  def invoke_simple(path, request_path)
    event = Sinatra::Event.new(path) { 'Simple' }
    event.invoke(simple_request_hash(:get, request_path))
  end
  
  specify "return last value" do
    result = invoke_simple('/', '/')
    result.should.not.be.nil
    result.body.should.equal 'Simple'
    result.params.should.equal Hash.new
  end
  
  specify "takes params in path" do
    result = invoke_simple('/:foo/:bar', '/a/b')
    result.should.not.be.nil
    result.params.should.equal :foo => 'a', :bar => 'b'
    
    # unscapes
    result = invoke_simple('/:foo/:bar', '/a/blake%20mizerany')
    result.should.not.be.nil
    result.params.should.equal :foo => 'a', :bar => 'blake mizerany'
  end
  
  specify "ignores to many /'s" do
    result = invoke_simple('/x/y', '/x//y')
    result.should.not.be.nil
  end
        
end
