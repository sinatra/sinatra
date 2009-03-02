begin
  require 'rack'
rescue LoadError
  require 'rubygems'
  require 'rack'
end

libdir = File.dirname(File.dirname(__FILE__)) + '/lib'
$LOAD_PATH.unshift libdir unless $LOAD_PATH.include?(libdir)

require 'test/unit'
require 'sinatra/test'

class Sinatra::Base
  # Allow assertions in request context
  include Test::Unit::Assertions
end

class Test::Unit::TestCase
  include Sinatra::Test

  # Sets up a Sinatra::Base subclass defined with the block
  # given. Used in setup or individual spec methods to establish
  # the application.
  def mock_app(base=Sinatra::Base, &block)
    @app = Sinatra.new(base, &block)
  end

  def restore_default_options
    Sinatra::Default.set(
      :environment => :development,
      :raise_errors => Proc.new { test? },
      :dump_errors => true,
      :sessions => false,
      :logging => Proc.new { ! test? },
      :methodoverride => true,
      :static => true,
      :run => Proc.new { ! test? }
    )
  end
end

##
# test/spec/mini
# http://pastie.caboo.se/158871
# chris@ozmm.org
#
def describe(*args, &block)
  return super unless (name = args.first.capitalize) && block
  name = "#{name.gsub(/\W/, '')}Test"
  Object.send :const_set, name, Class.new(Test::Unit::TestCase)
  klass = Object.const_get(name)
  klass.class_eval do
    def self.it(name, &block)
      define_method("test_#{name.gsub(/\W/,'_').downcase}", &block)
    end
    def self.xspecify(*args) end
    def self.before(&block) define_method(:setup, &block)    end
    def self.after(&block)  define_method(:teardown, &block) end
  end
  klass.class_eval &block
  klass
end

def describe_option(name, &block)
  klass = describe("Option #{name}", &block)
  klass.before do
    restore_default_options
    @base    = Sinatra.new
    @default = Class.new(Sinatra::Default)
  end
  klass
end

# Do not output warnings for the duration of the block.
def silence_warnings
  $VERBOSE, v = nil, $VERBOSE
  yield
ensure
  $VERBOSE = v
end
