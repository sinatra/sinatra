require 'test/spec'
require 'sinatra/base'
require 'sinatra/test'

describe 'Exception Mappings' do
  include Sinatra::Test

  class FooError < RuntimeError
  end

  it 'invokes handlers registered with ::error when raised' do
    mock_app {
      set :raise_errors, false
      error(FooError) { 'Foo!' }
      get '/' do
        raise FooError
      end
    }
    get '/'
    status.should.equal 500
    body.should.equal 'Foo!'
  end

  it 'uses the Exception handler if no matching handler found' do
    mock_app {
      set :raise_errors, false
      error(Exception) { 'Exception!' }
      get '/' do
        raise FooError
      end
    }
    get '/'
    status.should.equal 500
    body.should.equal 'Exception!'
  end

  it "sets env['sinatra.error'] to the rescued exception" do
    mock_app {
      set :raise_errors, false
      error(FooError) {
        env.should.include 'sinatra.error'
        env['sinatra.error'].should.be.kind_of FooError
        'looks good'
      }
      get '/' do
        raise FooError
      end
    }
    get '/'
    body.should.equal 'looks good'
  end

  it 'dumps errors to rack.errors when dump_errors is enabled' do
    mock_app {
      set :raise_errors, false
      set :dump_errors, true
      get('/') { raise FooError, 'BOOM!' }
    }

    get '/'
    status.should.equal 500
    @response.errors.should.match(/FooError - BOOM!:/)
  end

  it "raises without calling the handler when the raise_errors options is set" do
    mock_app {
      set :raise_errors, true
      error(FooError) { "she's not there." }
      get '/' do
        raise FooError
      end
    }
    lambda { get '/' }.should.raise FooError
  end

  it "never raises Sinatra::NotFound beyond the application" do
    mock_app {
      set :raise_errors, true
      get '/' do
        raise Sinatra::NotFound
      end
    }
    lambda { get '/' }.should.not.raise Sinatra::NotFound
    status.should.equal 404
  end

  class FooNotFound < Sinatra::NotFound
  end

  it "cascades for subclasses of Sinatra::NotFound" do
    mock_app {
      set :raise_errors, true
      error(FooNotFound) { "foo! not found." }
      get '/' do
        raise FooNotFound
      end
    }
    lambda { get '/' }.should.not.raise FooNotFound
    status.should.equal 404
    body.should.equal 'foo! not found.'
  end

end

describe 'Custom Error Pages' do
  it 'allows numeric status code mappings to be registered with ::error' do
    mock_app {
      set :raise_errors, false
      error(500) { 'Foo!' }
      get '/' do
        [500, {}, 'Internal Foo Error']
      end
    }
    get '/'
    status.should.equal 500
    body.should.equal 'Foo!'
  end

  it 'allows ranges of status code mappings to be registered with :error' do
    mock_app {
      set :raise_errors, false
      error(500..550) { "Error: #{response.status}" }
      get '/' do
        [507, {}, 'A very special error']
      end
    }
    get '/'
    status.should.equal 507
    body.should.equal 'Error: 507'
  end

  class FooError < RuntimeError
  end

  it 'runs after exception mappings and overwrites body' do
    mock_app {
      set :raise_errors, false
      error FooError do
        response.status = 502
        'from exception mapping'
      end
      error(500) { 'from 500 handler' }
      error(502) { 'from custom error page' }

      get '/' do
        raise FooError
      end
    }
    get '/'
    status.should.equal 502
    body.should.equal 'from custom error page'
  end
end
