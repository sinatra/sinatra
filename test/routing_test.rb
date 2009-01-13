require File.dirname(__FILE__) + '/helper'

describe "Routing" do
  %w[get put post delete head].each do |verb|
    it "defines #{verb.upcase} request handlers with #{verb}" do
      mock_app {
        send verb, '/hello' do
          'Hello World'
        end
      }

      request = Rack::MockRequest.new(@app)
      response = request.request(verb.upcase, '/hello', {})
      response.should.be.ok
      response.body.should.equal 'Hello World'
    end
  end

  it "404s when no route satisfies the request" do
    mock_app {
      get('/foo') { }
    }
    get '/bar'
    status.should.equal 404
  end

  it "exposes params with indifferent hash" do
    mock_app {
      get '/:foo' do
        params['foo'].should.equal 'bar'
        params[:foo].should.equal 'bar'
        'well, alright'
      end
    }
    get '/bar'
    body.should.equal 'well, alright'
  end

  it "merges named params and query string params in params" do
    mock_app {
      get '/:foo' do
        params['foo'].should.equal 'bar'
        params['baz'].should.equal 'biz'
      end
    }
    get '/bar?baz=biz'
    should.be.ok
  end

  it "supports named params like /hello/:person" do
    mock_app {
      get '/hello/:person' do
        "Hello #{params['person']}"
      end
    }
    get '/hello/Frank'
    body.should.equal 'Hello Frank'
  end

  it "supports optional named params like /?:foo?/?:bar?" do
    mock_app {
      get '/?:foo?/?:bar?' do
        "foo=#{params[:foo]};bar=#{params[:bar]}"
      end
    }

    get '/hello/world'
    should.be.ok
    body.should.equal "foo=hello;bar=world"

    get '/hello'
    should.be.ok
    body.should.equal "foo=hello;bar="

    get '/'
    should.be.ok
    body.should.equal "foo=;bar="
  end

  it "supports single splat params like /*" do
    mock_app {
      get '/*' do
        params['splat'].should.be.kind_of Array
        params['splat'].join "\n"
      end
    }

    get '/foo'
    body.should.equal "foo"

    get '/foo/bar/baz'
    body.should.equal "foo/bar/baz"
  end

  it "supports mixing multiple splat params like /*/foo/*/*" do
    mock_app {
      get '/*/foo/*/*' do
        params['splat'].should.be.kind_of Array
        params['splat'].join "\n"
      end
    }

    get '/bar/foo/bling/baz/boom'
    body.should.equal "bar\nbling\nbaz/boom"

    get '/bar/foo/baz'
    should.be.not_found
  end

  it "supports mixing named and splat params like /:foo/*" do
    mock_app {
      get '/:foo/*' do
        params['foo'].should.equal 'foo'
        params['splat'].should.equal ['bar/baz']
      end
    }

    get '/foo/bar/baz'
    should.be.ok
  end

  it "supports paths that include spaces" do
    mock_app {
      get '/path with spaces' do
        'looks good'
      end
    }

    get '/path%20with%20spaces'
    should.be.ok
    body.should.equal 'looks good'
  end

  it "URL decodes named parameters and splats" do
    mock_app {
      get '/:foo/*' do
        params['foo'].should.equal 'hello world'
        params['splat'].should.equal ['how are you']
        nil
      end
    }

    get '/hello%20world/how%20are%20you'
    should.be.ok
  end

  it 'supports regular expressions' do
    mock_app {
      get(/^\/foo...\/bar$/) do
        'Hello World'
      end
    }

    get '/foooom/bar'
    should.be.ok
    body.should.equal 'Hello World'
  end

  it 'makes regular expression captures available in params[:captures]' do
    mock_app {
      get(/^\/fo(.*)\/ba(.*)/) do
        params[:captures].should.equal ['orooomma', 'f']
        'right on'
      end
    }

    get '/foorooomma/baf'
    should.be.ok
    body.should.equal 'right on'
  end

  it "returns response immediately on halt" do
    mock_app {
      get '/' do
        halt 'Hello World'
        'Boo-hoo World'
      end
    }

    get '/'
    should.be.ok
    body.should.equal 'Hello World'
  end

  it "transitions to the next matching route on pass" do
    mock_app {
      get '/:foo' do
        pass
        'Hello Foo'
      end

      get '/*' do
        params.should.not.include 'foo'
        'Hello World'
      end
    }

    get '/bar'
    should.be.ok
    body.should.equal 'Hello World'
  end

  it "transitions to 404 when passed and no subsequent route matches" do
    mock_app {
      get '/:foo' do
        pass
        'Hello Foo'
      end
    }

    get '/bar'
    should.be.not_found
  end

  it "passes when matching condition returns false" do
    mock_app {
      condition { params[:foo] == 'bar' }
      get '/:foo' do
        'Hello World'
      end
    }

    get '/bar'
    should.be.ok
    body.should.equal 'Hello World'

    get '/foo'
    should.be.not_found
  end

  it "does not pass when matching condition returns nil" do
    mock_app {
      condition { nil }
      get '/:foo' do
        'Hello World'
      end
    }

    get '/bar'
    should.be.ok
    body.should.equal 'Hello World'
  end

  it "passes to next route when condition calls pass explicitly" do
    mock_app {
      condition { pass unless params[:foo] == 'bar' }
      get '/:foo' do
        'Hello World'
      end
    }

    get '/bar'
    should.be.ok
    body.should.equal 'Hello World'

    get '/foo'
    should.be.not_found
  end

  it "passes to the next route when host_name does not match" do
    mock_app {
      host_name 'example.com'
      get '/foo' do
        'Hello World'
      end
    }
    get '/foo'
    should.be.not_found

    get '/foo', :env => { 'HTTP_HOST' => 'example.com' }
    status.should.equal 200
    body.should.equal 'Hello World'
  end

  it "passes to the next route when user_agent does not match" do
    mock_app {
      user_agent(/Foo/)
      get '/foo' do
        'Hello World'
      end
    }
    get '/foo'
    should.be.not_found

    get '/foo', :env => { 'HTTP_USER_AGENT' => 'Foo Bar' }
    status.should.equal 200
    body.should.equal 'Hello World'
  end

  it "makes captures in user agent pattern available in params[:agent]" do
    mock_app {
      user_agent(/Foo (.*)/)
      get '/foo' do
        'Hello ' + params[:agent].first
      end
    }
    get '/foo', :env => { 'HTTP_USER_AGENT' => 'Foo Bar' }
    status.should.equal 200
    body.should.equal 'Hello Bar'
  end

  it "filters by accept header" do
    mock_app {
      get '/', :provides => :xml do
        request.env['HTTP_ACCEPT']
      end
    }

    get '/', :env => { :accept => 'application/xml' }
    should.be.ok
    body.should.equal 'application/xml'
    response.headers['Content-Type'].should.equal 'application/xml'

    get '/', :env => { :accept => 'text/html' }
    should.not.be.ok
  end

  it "allows multiple mime types for accept header" do
    types = ['image/jpeg', 'image/pjpeg']

    mock_app {
      get '/', :provides => types do
        request.env['HTTP_ACCEPT']
      end
    }

    types.each do |type|
      get '/', :env => { :accept => type }
      should.be.ok
      body.should.equal type
      response.headers['Content-Type'].should.equal type
    end
  end
end
