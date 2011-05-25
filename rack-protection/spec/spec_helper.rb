require 'rack/protection'
require 'rack/test'
require 'forwardable'

module DummyApp
  def self.call(env)
    Thread.current[:last_env] = env
    [200, {'Content-Type' => 'text/plain'}, ['ok']]
  end
end

module TestHelpers
  extend Forwardable
  def_delegators :last_response, :body, :headers, :status, :errors
  def_delegators :current_session, :env_for
  attr_writer :app

  def app
    @app || mock_app(DummyApp)
  end

  def mock_app(app = nil, &block)
    app  = block if app.nil? and block.arity == 1
    app  = app ? Rack::Head.new(described_class.new(app)) : Rack::Builder.new(&block).to_app
    @app = Rack::Lint.new(app)
  end

  def with_headers(headers)
    proc { [200, {'Content-Type' => 'text/plain'}.merge(headers), ['ok']] }
  end

  def env
    Thread.current[:last_env]
  end
end

# see http://blog.101ideas.cz/posts/pending-examples-via-not-implemented-error-in-rspec.html
module NotImplementedAsPending
  def self.included(base)
    base.class_eval do
      alias_method :__finish__, :finish
      remove_method :finish
    end
  end

  def finish(reporter)
    if @exception.is_a?(NotImplementedError)
      from = @exception.backtrace[0]
      message = "#{@exception.message} (from #{from})"
      @pending_declared_in_example = message
      metadata[:pending] = true
      @exception = nil
    end

    __finish__(reporter)
  end

  RSpec::Core::Example.send :include, self
end

RSpec.configure do |config|
  config.expect_with :rspec, :stdlib
  config.include Rack::Test::Methods
  config.include TestHelpers
end

shared_examples_for 'any rack application' do
  it "should not interfere with normal get requests" do
    get('/').should be_ok
    body.should == 'ok'
  end

  it "should not interfere with normal head requests" do
    head('/').should be_ok
  end

  it 'should not leak changes to env' do
    klass    = described_class
    detector = Struct.new(:app)

    detector.send(:define_method, :call) do |env|
      was = env.dup
      res = app.call(env)
      was.each do |k,v|
        next if env[k] == v
        fail "env[#{k.inspect}] changed from #{v.inspect} to #{env[k].inspect}"
      end
      res
    end

    mock_app do
      use detector
      use klass
      run DummyApp
    end

    get('/..', :foo => '<bar>').should be_ok
  end

  it 'allows passing on values in env' do
    klass    = described_class
    detector = Struct.new(:app)
    changer  = Struct.new(:app)

    detector.send(:define_method, :call) do |env|
      res = app.call(env)
      env['foo.bar'].should == 42
      res
    end

    changer.send(:define_method, :call) do |env|
      env['foo.bar'] = 42
      app.call(env)
    end

    mock_app do
      use detector
      use klass
      use changer
      run DummyApp
    end

    get('/').should be_ok
  end
end
