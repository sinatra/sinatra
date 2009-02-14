require File.dirname(__FILE__) + '/helper'

describe 'Options' do
  before { @app = Class.new(Sinatra::Base) }

  it 'sets options to literal values' do
    @app.set(:foo, 'bar')
    assert @app.respond_to?(:foo)
    assert_equal 'bar', @app.foo
  end

  it 'sets options to Procs' do
    @app.set(:foo, Proc.new { 'baz' })
    assert @app.respond_to?(:foo)
    assert_equal 'baz', @app.foo
  end

  it "sets multiple options with a Hash" do
    @app.set :foo => 1234,
        :bar => 'Hello World',
        :baz => Proc.new { 'bizzle' }
    assert_equal 1234, @app.foo
    assert_equal 'Hello World', @app.bar
    assert_equal 'bizzle', @app.baz
  end

  it 'inherits option methods when subclassed' do
    @app.set :foo, 'bar'
    @app.set :biz, Proc.new { 'baz' }

    sub = Class.new(@app)
    assert sub.respond_to?(:foo)
    assert_equal 'bar', sub.foo
    assert sub.respond_to?(:biz)
    assert_equal 'baz', sub.biz
  end

  it 'overrides options in subclass' do
    @app.set :foo, 'bar'
    @app.set :biz, Proc.new { 'baz' }
    sub = Class.new(@app)
    sub.set :foo, 'bling'
    assert_equal 'bling', sub.foo
    assert_equal 'bar', @app.foo
  end

  it 'creates setter methods when first defined' do
    @app.set :foo, 'bar'
    assert @app.respond_to?('foo=')
    @app.foo = 'biz'
    assert_equal 'biz', @app.foo
  end

  it 'creates predicate methods when first defined' do
    @app.set :foo, 'hello world'
    assert @app.respond_to?(:foo?)
    assert @app.foo?
    @app.set :foo, nil
    assert !@app.foo?
  end

  it 'uses existing setter methods if detected' do
    class << @app
      def foo
        @foo
      end
      def foo=(value)
        @foo = 'oops'
      end
    end

    @app.set :foo, 'bam'
    assert_equal 'oops', @app.foo
  end

  it "sets multiple options to true with #enable" do
    @app.enable :sessions, :foo, :bar
    assert @app.sessions
    assert @app.foo
    assert @app.bar
  end

  it "sets multiple options to false with #disable" do
    @app.disable :sessions, :foo, :bar
    assert !@app.sessions
    assert !@app.foo
    assert !@app.bar
  end

  it 'enables MethodOverride middleware when :methodoverride is enabled' do
    @app.set :methodoverride, true
    @app.put('/') { 'okay' }
    post '/', {'_method'=>'PUT'}, {}
    assert_equal 200, status
    assert_equal 'okay', body
  end
end

describe 'clean_trace' do
  before do
    @app = Class.new(Sinatra::Base)
  end

  def clean_backtrace(trace)
    @app.new.send(:clean_backtrace, trace)
  end

  it 'is enabled by default' do
    assert @app.clean_trace
  end

  it 'does nothing when disabled' do
    backtrace = [
      "./lib/sinatra/base.rb",
      "./myapp:42",
      ("#{Gem.dir}/some/lib.rb" if defined?(Gem))
    ].compact
    @app.set :clean_trace, false
    assert_equal backtrace, clean_backtrace(backtrace)
  end

  it 'removes sinatra lib paths from backtrace when enabled' do
    backtrace = [
      "./lib/sinatra/base.rb",
      "./lib/sinatra/compat.rb:42",
      "./lib/sinatra/main.rb:55 in `foo'"
    ]
    assert clean_backtrace(backtrace).empty?
  end

  it 'removes ./ prefix from backtrace paths when enabled' do
    assert_equal ['myapp.rb:42'], clean_backtrace(['./myapp.rb:42'])
  end

  if defined?(Gem)
    it 'removes gem lib paths from backtrace when enabled' do
      assert clean_backtrace(["#{Gem.dir}/some/lib"]).empty?
    end
  end
end
