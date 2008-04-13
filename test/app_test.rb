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

  specify "gives access to underlying response header Hash" do
    get '/' do
      header['X-Test'] = 'Is this thing on?'
      headers 'X-Test2' => 'Foo', 'X-Test3' => 'Bar'
      ''
    end

    get_it '/'
    should.be.ok
    headers.should.include 'X-Test'
    headers['X-Test'].should.equal 'Is this thing on?'
    headers.should.include 'X-Test3'
    headers['X-Test3'].should.equal 'Bar'
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

  specify "redirects permanently with 301 status code" do
    get "/" do
      redirect 'foo', 301
    end
    get_it '/'
    should.be.redirection
    headers['Location'].should.equal 'foo'
    status.should.equal 301
    body.should.be.empty
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

  specify "should easily set response Content-Type" do
    get '/foo.html' do
      content_type 'text/html', :charset => 'utf-8'
      "<h1>Hello, World</h1>"
    end

    get_it '/foo.html'
    should.be.ok
    headers['Content-Type'].should.equal 'text/html;charset=utf-8'
    body.should.equal '<h1>Hello, World</h1>'

    get '/foo.xml' do
      content_type :xml
      "<feed></feed>"
    end

    get_it '/foo.xml'
    should.be.ok
    headers['Content-Type'].should.equal 'application/xml'
    body.should.equal '<feed></feed>'
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
