require 'test/spec'
require 'sinatra/base'
require 'sinatra/test'

describe 'Result Handling' do
  include Sinatra::Test

  it "sets response.body when result is a String" do
    mock_app {
      get '/' do
        'Hello World'
      end
    }

    get '/'
    should.be.ok
    body.should.equal 'Hello World'
  end

  it "sets response.body when result is an Array of Strings" do
    mock_app {
      get '/' do
        ['Hello', 'World']
      end
    }

    get '/'
    should.be.ok
    body.should.equal 'HelloWorld'
  end

  it "sets response.body when result responds to #each" do
    mock_app {
      get '/' do
        res = lambda { 'Hello World' }
        def res.each ; yield call ; end
        res
      end
    }

    get '/'
    should.be.ok
    body.should.equal 'Hello World'
  end

  it "sets response.body to [] when result is nil" do
    mock_app {
      get '/' do
        nil
      end
    }

    get '/'
    should.be.ok
    body.should.equal ''
  end

  it "sets status, headers, and body when result is a Rack response tuple" do
    mock_app {
      get '/' do
        [205, {'Content-Type' => 'foo/bar'}, 'Hello World']
      end
    }

    get '/'
    status.should.equal 205
    response['Content-Type'].should.equal 'foo/bar'
    body.should.equal 'Hello World'
  end

  it "sets status and body when result is a two-tuple" do
    mock_app {
      get '/' do
        [409, 'formula of']
      end
    }

    get '/'
    status.should.equal 409
    body.should.equal 'formula of'
  end

  it "sets status when result is a Fixnum status code" do
    mock_app {
      get('/') { 205 }
    }

    get '/'
    status.should.equal 205
    body.should.be.empty
  end
end
