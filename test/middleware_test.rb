require_relative 'test_helper'

class MiddlewareTest < Minitest::Test
  setup do
    @app = mock_app(Sinatra::Application) do
      get('/*')do
        response.headers['X-Tests'] = env['test.ran'].
          map { |n| n.split('::').last }.
          join(', ')
        env['PATH_INFO']
      end
    end
  end

  class MockMiddleware < Struct.new(:app)
    def call(env)
      (env['test.ran'] ||= []) << self.class.to_s
      app.call(env)
    end
  end

  class UpcaseMiddleware < MockMiddleware
    def call(env)
      env['PATH_INFO'] = env['PATH_INFO'].upcase
      super
    end
  end

  it "is added with Sinatra::Application.use" do
    @app.use UpcaseMiddleware
    get '/hello-world'
    assert ok?
    assert_equal '/HELLO-WORLD', body
  end

  class DowncaseMiddleware < MockMiddleware
    def call(env)
      env['PATH_INFO'] = env['PATH_INFO'].downcase
      super
    end
  end

  it "runs in the order defined" do
    @app.use UpcaseMiddleware
    @app.use DowncaseMiddleware
    get '/Foo'
    assert_equal "/foo", body
    assert_equal "UpcaseMiddleware, DowncaseMiddleware", response['X-Tests']
  end

  it "resets the prebuilt pipeline when new middleware is added" do
    @app.use UpcaseMiddleware
    get '/Foo'
    assert_equal "/FOO", body
    @app.use DowncaseMiddleware
    get '/Foo'
    assert_equal '/foo', body
    assert_equal "UpcaseMiddleware, DowncaseMiddleware", response['X-Tests']
  end

  it "works when app is used as middleware" do
    @app.use UpcaseMiddleware
    @app = @app.new
    get '/Foo'
    assert_equal "/FOO", body
    assert_equal "UpcaseMiddleware", response['X-Tests']
  end

  class FreezeMiddleware < MockMiddleware
    def call(env)
      req = Rack::Request.new(env)
      req.update_param('bar', 'baz'.freeze)
      super
    end
  end

  it "works when middleware adds a frozen param" do
    @app.use FreezeMiddleware
    get '/Foo'
  end

  class SpecialConstsMiddleware < MockMiddleware
    def call(env)
      req = Rack::Request.new(env)
      req.update_param('s', :s)
      req.update_param('i', 1)
      req.update_param('c', 3.to_c)
      req.update_param('t', true)
      req.update_param('f', false)
      req.update_param('n', nil)
      super
    end
  end

  it "handles params when the params contains true/false values" do
    @app.use SpecialConstsMiddleware
    get '/'
  end

  class KeywordArgumentInitializationMiddleware < MockMiddleware
    def initialize(app, **)
      super app
    end
  end

  it "handles keyword arguments" do
    @app.use KeywordArgumentInitializationMiddleware, argument: "argument"
    get '/'
  end
end
