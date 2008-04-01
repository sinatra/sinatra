require File.dirname(__FILE__) + '/helper'

context "Sinatra" do
  
  setup do
    Sinatra.application = nil
  end
  
  specify "should handle result of nil" do
    get '/' do
      nil
    end
    
    get_it '/'
    should.be.ok
    body.should == ''
  end
  
  specify "handles events" do
    get '/:name' do
      'Hello ' + params["name"]
    end
    
    get_it '/Blake'
    
    should.be.ok
    body.should.equal 'Hello Blake'
  end
  
  specify "follows redirects" do
    get '/' do
      redirect '/blake'
    end
    
    get '/blake' do
      'Mizerany'
    end
    
    get_it '/'
    should.be.redirection
    body.should.equal ''
    
    follow!
    should.be.ok
    body.should.equal 'Mizerany'
  end
  
  specify "renders a body with a redirect" do
    Sinatra::EventContext.any_instance.expects(:foo).returns('blah')
    get "/" do
      redirect 'foo', :foo
    end
    get_it '/'
    should.be.redirection
    headers['Location'].should.equal 'foo'
    body.should.equal 'blah'
  end
  
  specify "body sets content and ends event" do
    
    Sinatra::EventContext.any_instance.expects(:foo).never
    
    get '/set_body' do
      stop 'Hello!'
      stop 'World!'
      foo
    end
    
    get_it '/set_body'
    
    should.be.ok
    body.should.equal 'Hello!'
    
  end
  
  specify "should set status then call helper with a var" do
    Sinatra::EventContext.any_instance.expects(:foo).once.with(1).returns('bah!')
    
    get '/set_body' do
      stop [404, [:foo, 1]]
    end
    
    get_it '/set_body'
    
    should.be.not_found
    body.should.equal 'bah!'
    
  end

  specify "delegates HEAD requests to GET handlers" do
    get '/invisible' do
      "I am invisible to the world"
    end

    head_it '/invisible'
    should.be.ok
    body.should.not.equal "I am invisible to the world"
    body.should.equal ''
  end

  
  specify "put'n with POST" do
    put '/' do
      'puted'
    end
    post_it '/', :_method => 'PUT'
    assert_equal 'puted', body
  end

  specify "put'n wth PUT" do
    put '/' do
      'puted'
    end
    put_it '/'
    assert_equal 'puted', body
  end

  # Some Ajax libraries downcase the _method parameter value. Make 
  # sure we can handle that.
  specify "put'n with POST and lowercase _method param" do
    put '/' do
      'puted'
    end
    post_it '/', :_method => 'put'
    body.should.equal 'puted'
  end

  # Ignore any _method parameters specified in GET requests or on the query string in POST requests.
  specify "not put'n with GET" do
    get '/' do
      'getted'
    end
    get_it '/', :_method => 'put'
    should.be.ok
    body.should.equal 'getted'
  end

  specify "_method query string parameter ignored on POST" do
    post '/' do
      'posted'
    end
    put '/' do
      'booo'
    end
    post_it "/?_method=PUT"
    should.be.ok
    body.should.equal 'posted'
  end

end
