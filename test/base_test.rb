require 'test/spec'
require 'sinatra/base'
require 'sinatra/test'

describe 'Sinatra::Base' do
  include Sinatra::Test

  it 'includes Rack::Utils' do
    Sinatra::Base.should.include Rack::Utils
  end

  it 'can be used as a Rack application' do
    mock_app {
      get '/' do
        'Hello World'
      end
    }
    @app.should.respond_to :call

    request = Rack::MockRequest.new(@app)
    response = request.get('/')
    response.should.be.ok
    response.body.should.equal 'Hello World'
  end

  it 'can be used as Rack middleware' do
    app = lambda { |env| [200, {}, ['Goodbye World']] }
    mock_middleware =
      mock_app {
        get '/' do
          'Hello World'
        end
        get '/goodbye' do
          @app.call(request.env)
        end
      }
    middleware = mock_middleware.new(app)
    middleware.app.should.be app

    request = Rack::MockRequest.new(middleware)
    response = request.get('/')
    response.should.be.ok
    response.body.should.equal 'Hello World'

    response = request.get('/goodbye')
    response.should.be.ok
    response.body.should.equal 'Goodbye World'
  end
end
