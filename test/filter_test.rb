require File.dirname(__FILE__) + '/helper'

class BeforeFilterTest < Test::Unit::TestCase
  it "executes filters in the order defined" do
    count = 0
    mock_app do
      get('/') { 'Hello World' }
      before {
        assert_equal 0, count
        count = 1
      }
      before {
        assert_equal 1, count
        count = 2
      }
    end

    get '/'
    assert ok?
    assert_equal 2, count
    assert_equal 'Hello World', body
  end

  it "can modify the request" do
    mock_app {
      get('/foo') { 'foo' }
      get('/bar') { 'bar' }
      before { request.path_info = '/bar' }
    }

    get '/foo'
    assert ok?
    assert_equal 'bar', body
  end

  it "can modify instance variables available to routes" do
    mock_app {
      before { @foo = 'bar' }
      get('/foo') { @foo }
    }

    get '/foo'
    assert ok?
    assert_equal 'bar', body
  end

  it "allows redirects" do
    mock_app {
      before { redirect '/bar' }
      get('/foo') do
        fail 'before block should have halted processing'
        'ORLY?!'
      end
    }

    get '/foo'
    assert redirect?
    assert_equal '/bar', response['Location']
    assert_equal '', body
  end

  it "does not modify the response with its return value" do
    mock_app {
      before { 'Hello World!' }
      get '/foo' do
        assert_equal [], response.body
        'cool'
      end
    }

    get '/foo'
    assert ok?
    assert_equal 'cool', body
  end

  it "does modify the response with halt" do
    mock_app {
      before { halt 302, 'Hi' }
      get '/foo' do
        "should not happen"
      end
    }

    get '/foo'
    assert_equal 302, response.status
    assert_equal 'Hi', body
  end

  it "gives you access to params" do
    mock_app {
      before { @foo = params['foo'] }
      get('/foo') { @foo }
    }

    get '/foo?foo=cool'
    assert ok?
    assert_equal 'cool', body
  end

  it "runs filters defined in superclasses" do
    base = Class.new(Sinatra::Base)
    base.before { @foo = 'hello from superclass' }

    mock_app(base) {
      get('/foo') { @foo }
    }

    get '/foo'
    assert_equal 'hello from superclass', body
  end

  it 'does not run before filter when serving static files' do
    ran_filter = false
    mock_app {
      before { ran_filter = true }
      set :static, true
      set :public, File.dirname(__FILE__)
    }
    get "/#{File.basename(__FILE__)}"
    assert ok?
    assert_equal File.read(__FILE__), body
    assert !ran_filter
  end
end

class AfterFilterTest < Test::Unit::TestCase
  it "executes filters in the order defined" do
    invoked = 0
    mock_app do
      before   { invoked = 2 }
      get('/') { invoked += 2 }
      after    { invoked *= 2 }
    end

    get '/'
    assert ok?

    assert_equal 8, invoked
  end

  it "executes filters in the order defined" do
    count = 0
    mock_app do
      get('/') { 'Hello World' }
      after {
        assert_equal 0, count
        count = 1
      }
      after {
        assert_equal 1, count
        count = 2
      }
    end

    get '/'
    assert ok?
    assert_equal 2, count
    assert_equal 'Hello World', body
  end

  it "allows redirects" do
    mock_app {
      get('/foo') { 'ORLY' }
      after { redirect '/bar' }
    }

    get '/foo'
    assert redirect?
    assert_equal '/bar', response['Location']
    assert_equal '', body
  end

  it "does not modify the response with its return value" do
    mock_app {
      get('/foo') { 'cool' }
      after { 'Hello World!' }
    }

    get '/foo'
    assert ok?
    assert_equal 'cool', body
  end

  it "does modify the response with halt" do
    mock_app {
      get '/foo' do
        "should not be returned"
      end
      after { halt 302, 'Hi' }
    }

    get '/foo'
    assert_equal 302, response.status
    assert_equal 'Hi', body
  end

  it "runs filters defined in superclasses" do
    count = 2
    base = Class.new(Sinatra::Base)
    base.after { count *= 2 }
    mock_app(base) {
      get('/foo') { count += 2 }
    }

    get '/foo'
    assert_equal 8, count
  end

  it 'does not run after filter when serving static files' do
    ran_filter = false
    mock_app {
      after { ran_filter = true }
      set :static, true
      set :public, File.dirname(__FILE__)
    }
    get "/#{File.basename(__FILE__)}"
    assert ok?
    assert_equal File.read(__FILE__), body
    assert !ran_filter
  end
end
