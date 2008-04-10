require File.dirname(__FILE__) + '/helper'

class TesterWithEach
  def each
    yield 'foo'
    yield 'bar'
    yield 'baz'
  end
end

context "Looking up a request" do

  setup do
    Sinatra.application = nil
  end

  specify "returns what's at the end" do
    block = Proc.new { 'Hello' }
    get '/', &block
    
    result = Sinatra.application.lookup(
      Rack::Request.new(
        'REQUEST_METHOD' => 'GET',
        'PATH_INFO' => '/'
      )
    )
    
    result.should.not.be.nil
    result.block.should.be block
  end
  
  specify "takes params in path" do
    block = Proc.new { 'Hello' }
    get '/:foo', &block
    
    result = Sinatra.application.lookup(
      Rack::Request.new(
        'REQUEST_METHOD' => 'GET',
        'PATH_INFO' => '/bar'
      )
    )
    
    result.should.not.be.nil
    result.block.should.be block
    result.params.should.equal "foo" => 'bar'
  end
              
end

context "An app returns" do
  
  setup do
    Sinatra.application = nil
  end
    
  specify "404 if no events found" do
    request = Rack::MockRequest.new(@app)
    get_it '/'
    should.be.not_found
    body.should.equal '<h1>Not Found</h1>'
  end
  
  specify "200 if success" do
    get '/' do
      'Hello World'
    end
    get_it '/'
    should.be.ok
    body.should.equal 'Hello World'
  end
  
  specify "an objects result from each if it has it" do
    
    get '/' do
      TesterWithEach.new
    end
    
    get_it '/'
    should.be.ok
    body.should.equal 'foobarbaz'

  end
  
  specify "the body set if set before the last" do
        
    get '/' do
      body 'Blake'
      'Mizerany'
    end
    
    get_it '/'
    should.be.ok
    body.should.equal 'Blake'

  end
  
end
  
context "Events in an app" do
  
  setup do
    Sinatra.application = nil
  end
  
  specify "evaluate in a clean context" do
    helpers do
      def foo
        'foo'
      end
    end
    
    get '/foo' do
      foo
    end
    
    get_it '/foo'
    should.be.ok
    body.should.equal 'foo'
  end
  
  specify "get access to request, response, and params" do
    get '/:foo' do
      params["foo"] + params["bar"]
    end
    
    get_it '/foo?bar=baz'
    should.be.ok
    body.should.equal 'foobaz'
  end
  
  specify "can filters by agent" do
    
    get '/', :agent => /Windows/ do
      request.env['HTTP_USER_AGENT']
    end
    
    get_it '/', :env => { :agent => 'Windows' }
    should.be.ok
    body.should.equal 'Windows'

    get_it '/', :agent => 'Mac'
    should.not.be.ok

  end

  specify "can filters by agent" do
    
    get '/', :agent => /Windows (NT)/ do
      params[:agent].first
    end
    
    get_it '/', :env => { :agent => 'Windows NT' }

    body.should.equal 'NT'

  end
  
end


