require File.dirname(__FILE__) + '/helper'

context "Looking up a request" do

  setup do
    @app = Sinatra::Application.new
  end

  specify "returns what's at the end" do
    block = Proc.new { 'Hello' }
    @app.define_event(:get, '/', &block)
        
    result = @app.lookup(
      'REQUEST_METHOD' => 'GET',
      'PATH_INFO' => '/'
    )
    
    result.should.not.be.nil
    result.block.should.be block
  end
  
  specify "takes params in path" do
    block = Proc.new { 'Hello' }
    @app.define_event(:get, '/:foo', &block)
    
    result = @app.lookup(
      'REQUEST_METHOD' => 'GET',
      'PATH_INFO' => '/bar'
    )
    
    result.should.not.be.nil
    result.block.should.be block
    result.params.should.equal :foo => 'bar'
  end
              
end
