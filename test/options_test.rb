require File.dirname(__FILE__) + '/helper'

describe 'Options' do
  before do
    restore_default_options
    @app = Sinatra.new
  end

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

describe_option 'clean_trace' do
  def clean_backtrace(trace)
    @base.new.send(:clean_backtrace, trace)
  end

  it 'is enabled on Base' do
    assert @base.clean_trace?
  end

  it 'is enabled on Default' do
    assert @default.clean_trace?
  end

  it 'does nothing when disabled' do
    backtrace = [
      "./lib/sinatra/base.rb",
      "./myapp:42",
      ("#{Gem.dir}/some/lib.rb" if defined?(Gem))
    ].compact
    @base.set :clean_trace, false
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

describe_option 'run' do
  it 'is disabled on Base' do
    assert ! @base.run?
  end

  it 'is enabled on Default when not in test environment' do
    assert @default.development?
    assert @default.run?

    @default.set :environment, :development
    assert @default.run?
  end

  # TODO: it 'is enabled when $0 == app_file'
end

describe_option 'raise_errors' do
  it 'is enabled on Base' do
    assert @base.raise_errors?
  end

  it 'is enabled on Default only in test' do
    @default.set(:environment, :development)
    assert @default.development?
    assert ! @default.raise_errors?, "disabled development"

    @default.set(:environment, :production)
    assert ! @default.raise_errors?

    @default.set(:environment, :test)
    assert @default.raise_errors?
  end
end

describe_option 'dump_errors' do
  it 'is disabled on Base' do
    assert ! @base.dump_errors?
  end

  it 'is enabled on Default' do
    assert @default.dump_errors?
  end

  it 'dumps exception with backtrace to rack.errors' do
    Sinatra::Default.disable(:raise_errors)

    mock_app(Sinatra::Default) {
      error do
        error = @env['rack.errors'].instance_variable_get(:@error)
        error.rewind

        error.read
      end

      get '/' do
        raise
      end
    }

    get '/'
    assert body.include?("RuntimeError") && body.include?("options_test.rb")
  end
end

describe_option 'sessions' do
  it 'is disabled on Base' do
    assert ! @base.sessions?
  end

  it 'is disabled on Default' do
    assert ! @default.sessions?
  end

  # TODO: it 'uses Rack::Session::Cookie when enabled' do
end

describe_option 'logging' do
  it 'is disabled on Base' do
    assert ! @base.logging?
  end

  it 'is enabled on Default when not in test environment' do
    assert @default.logging?

    @default.set :environment, :test
    assert ! @default.logging
  end

  # TODO: it 'uses Rack::CommonLogger when enabled' do
end

describe_option 'static' do
  it 'is disabled on Base' do
    assert ! @base.static?
  end

  it 'is enabled on Default' do
    assert @default.static?
  end

  # TODO: it setup static routes if public is enabled
  # TODO: however, that's already tested in static_test so...
end

describe_option 'host' do
  it 'defaults to 0.0.0.0' do
    assert_equal '0.0.0.0', @base.host
    assert_equal '0.0.0.0', @default.host
  end
end

describe_option 'port' do
  it 'defaults to 4567' do
    assert_equal 4567, @base.port
    assert_equal 4567, @default.port
  end
end

describe_option 'server' do
  it 'is one of thin, mongrel, webrick' do
    assert_equal %w[thin mongrel webrick], @base.server
    assert_equal %w[thin mongrel webrick], @default.server
  end
end

describe_option 'app_file' do
  it 'is nil' do
    assert @base.app_file.nil?
    assert @default.app_file.nil?
  end
end

describe_option 'root' do
  it 'is nil if app_file is not set' do
    assert @base.root.nil?
    assert @default.root.nil?
  end

  it 'is equal to the expanded basename of app_file' do
    @base.app_file = __FILE__
    assert_equal File.expand_path(File.dirname(__FILE__)), @base.root

    @default.app_file = __FILE__
    assert_equal File.expand_path(File.dirname(__FILE__)), @default.root
  end
end

describe_option 'views' do
  it 'is nil if root is not set' do
    assert @base.views.nil?
    assert @default.views.nil?
  end

  it 'is set to root joined with views/' do
    @base.root = File.dirname(__FILE__)
    assert_equal File.dirname(__FILE__) + "/views", @base.views

    @default.root = File.dirname(__FILE__)
    assert_equal File.dirname(__FILE__) + "/views", @default.views
  end
end

describe_option 'public' do
  it 'is nil if root is not set' do
    assert @base.public.nil?
    assert @default.public.nil?
  end

  it 'is set to root joined with public/' do
    @base.root = File.dirname(__FILE__)
    assert_equal File.dirname(__FILE__) + "/public", @base.public

    @default.root = File.dirname(__FILE__)
    assert_equal File.dirname(__FILE__) + "/public", @default.public
  end
end

describe_option 'reload' do
  it 'is enabled when
        app_file is set,
        is not a rackup file,
        and we are in development' do
    @base.app_file = __FILE__
    @base.set(:environment, :development)
    assert @base.reload?

    @default.app_file = __FILE__
    @default.set(:environment, :development)
    assert @default.reload?
  end

  it 'is disabled if app_file is not set' do
    assert ! @base.reload?
    assert ! @default.reload?
  end

  it 'is disabled if app_file is a rackup file' do
    @base.app_file = 'config.ru'
    assert ! @base.reload?

    @default.app_file = 'config.ru'
    assert ! @base.reload?
  end

  it 'is disabled if we are not in development' do
    @base.set(:environment, :foo)
    assert ! @base.reload

    @default.set(:environment, :bar)
    assert ! @default.reload
  end
end

describe_option 'lock' do
  it 'is enabled when reload is enabled' do
    @base.enable(:reload)
    assert @base.lock?

    @default.enable(:reload)
    assert @default.lock?
  end

  it 'is disabled when reload is disabled' do
    @base.disable(:reload)
    assert ! @base.lock?

    @default.disable(:reload)
    assert ! @default.lock?
  end
end
