require 'test/spec'
require 'sinatra/base'
require 'sinatra/test'

describe 'Options' do
  include Sinatra::Test

  before do
    @app = Class.new(Sinatra::Base)
  end

  it 'sets options to literal values' do
    @app.set(:foo, 'bar')
    @app.should.respond_to? :foo
    @app.foo.should.equal 'bar'
  end

  it 'sets options to Procs' do
    @app.set(:foo, Proc.new { 'baz' })
    @app.should.respond_to? :foo
    @app.foo.should.equal 'baz'
  end

  it "sets multiple options with a Hash" do
    @app.set :foo => 1234,
        :bar => 'Hello World',
        :baz => Proc.new { 'bizzle' }
    @app.foo.should.equal 1234
    @app.bar.should.equal 'Hello World'
    @app.baz.should.equal 'bizzle'
  end

  it 'inherits option methods when subclassed' do
    @app.set :foo, 'bar'
    @app.set :biz, Proc.new { 'baz' }

    sub = Class.new(@app)
    sub.should.respond_to :foo
    sub.foo.should.equal 'bar'
    sub.should.respond_to :biz
    sub.biz.should.equal 'baz'
  end

  it 'overrides options in subclass' do
    @app.set :foo, 'bar'
    @app.set :biz, Proc.new { 'baz' }
    sub = Class.new(@app)
    sub.set :foo, 'bling'
    sub.foo.should.equal 'bling'
    @app.foo.should.equal 'bar'
  end

  it 'creates setter methods when first defined' do
    @app.set :foo, 'bar'
    @app.should.respond_to 'foo='
    @app.foo = 'biz'
    @app.foo.should.equal 'biz'
  end

  it 'creates predicate methods when first defined' do
    @app.set :foo, 'hello world'
    @app.should.respond_to :foo?
    @app.foo?.should.be true
    @app.set :foo, nil
    @app.foo?.should.be false
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
    @app.foo.should.equal 'oops'
  end

  it "sets multiple options to true with #enable" do
    @app.enable :sessions, :foo, :bar
    @app.sessions.should.be true
    @app.foo.should.be true
    @app.bar.should.be true
  end

  it "sets multiple options to false with #disable" do
    @app.disable :sessions, :foo, :bar
    @app.sessions.should.be false
    @app.foo.should.be false
    @app.bar.should.be false
  end

  it 'enables MethodOverride middleware when :methodoverride is enabled' do
    @app.set :methodoverride, true
    @app.put('/') { 'okay' }
    post '/', {'_method'=>'PUT'}, {}
    status.should.equal 200
    body.should.equal 'okay'
  end
end
