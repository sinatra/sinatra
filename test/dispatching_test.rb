require File.dirname(__FILE__) + '/helper'

context "Dispatching" do
    
  include Sinatra::Test::Methods
      
  def dont_raise_errors
    Sinatra.config[:raise_errors] = false
    yield
    Sinatra.config[:raise_errors] = true
  end
    
  setup do
    Sinatra.routes.clear
    Sinatra.setup_default_events!
  end
    
  specify "should return the correct block" do
    r = get '/' do
      'main'
    end
            
    result = Sinatra.determine_route(:get, '/')
    result.block.should.be r.block
  end
  
  specify "should return custom 404" do
    Sinatra.routes[404] = r = Proc.new { 'custom 404' }
        
    result = Sinatra.determine_route(:get, '/')
    result.should.be r
  end
  
  specify "should return standard 404" do
    get_it '/'
    body.should.equal '<h1>Not Found</h1>'
  end
  
  specify "should give custom 500 if error when called" do
    Sinatra.routes[500] = r = Proc.new { 'custom 500' }

    get '/' do
      raise 'asdf'
    end
    
    dont_raise_errors do
      get_it '/'
    end

    body.should.equal 'custom 500'
  end
  
  specify "should give standard 500 if error when called" do
    get '/' do
      raise 'asdf'
    end
    
    dont_raise_errors do
      get_it '/'
    end

    body.should.match(/^asdf/)
  end
  
  specify "should run in a context" do
    Sinatra::EventContext.any_instance.expects(:foo).returns 'in foo'
    
    get '/' do
      foo
    end
    
    get_it '/'
    body.should.equal 'in foo'
  end
  
  specify "has access to the request" do
    
    get '/blake' do
      request.path_info
    end
    
    get_it '/blake'
    
    body.should.equal '/blake'
    
  end
  
  specify "has DSLified methods for response" do
    get '/' do
      status 555
      'uh oh'
    end
    
    get_it '/'

    body.should.equal "uh oh"
    status.should.equal 555
  end
          
end

context "An Event in test mode" do
  
  include Sinatra::Test::Methods

  setup do
    Sinatra.routes.clear
    Sinatra.setup_default_events!
  end

  specify "should raise errors to top" do
    get '/' do
      raise 'asdf'
    end
      
    lambda { get_it '/' }.should.raise(RuntimeError)
  end

end