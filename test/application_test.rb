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


context "Calling an app" do
  
  setup do
    @app = Sinatra::Application.new
  end
  
  # - 404 if no events found
  
  specify "404 if no events found" do
    request = Rack::MockRequest.new(@app)
    result = request.get('/')
    result.should.be.not_found
    result.body.should.equal 'Not Found'
  end
  
  specify "200 if success" do
    @app.define_event(:get, '/') do
      'Hello World'
    end
    
    request = Rack::MockRequest.new(@app)
    result = request.get('/')
    result.should.be.ok
    result.body.should.equal 'Hello World'
  end
  
  specify "evaluates events in a clean context" do
    Sinatra::EventContext.class_eval do
      def foo
        'foo'
      end
    end
    
    @app.define_event(:get, '/foo') do
      foo
    end
    
    request = Rack::MockRequest.new(@app)
    result = request.get('/foo')
    result.should.be.ok
    result.body.should.equal 'foo'
  end
  
  specify "gives the event access to request, response, and params" do
    @app.define_event(:get, '/:foo') do
      params[:foo] + params[:bar]
    end
    
    request = Rack::MockRequest.new(@app)
    result = request.get('/foo?bar=baz')
    result.should.be.ok
    result.body.should.equal 'foobaz'
  end
  
end
