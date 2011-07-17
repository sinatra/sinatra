require 'sinatra/base'
require 'backports/basic_object' unless defined? BasicObject

module Sinatra

  # = Sinatra::Extension
  #
  # <tt>Sinatra::Extension</tt> is a mixin that provides some syntactic sugar
  # for your extensions.  It allows you to call directly inside your extension
  # module almost any <tt>Sinatra::Base</tt> method.  This means you can use
  # +get+ to define a route, +before+ to define a before filter, +set+ to
  # define a setting, a so on.
  #
  # Is important to be aware that this mixin remembers the methods calls you
  # make, and then, when your extension is registered, replays them on the
  # Sinatra application that has been extended.  In order to do that, it
  # defines a <tt>registered</tt> method, so, if your extension defines one
  # too, remember to call +super+.
  #
  # == Usage
  #
  # Just require the mixin and extend your extension with it:
  #
  #     require 'sinatra/extension'
  #
  #     module MyExtension
  #       extend Sinatra::Extension
  #
  #       # set some settings for development
  #       configure :development do
  #         set :reload_stuff, true
  #       end
  #
  #       # define a route
  #       get '/' do
  #         'Hello World'
  #       end
  #
  #       # The rest of your extension code goes here...
  #     end
  #
  # You can also create an extension with the +new+ method:
  #
  #     MyExtension = Sinatra::Extension.new do
  #       # Your extension code goes here...
  #     end
  #
  # This is useful when you just want to pass a block to
  # <tt>Sinatra::Base.register</tt>.
  module Extension
    def self.new(&block)
      ext = Module.new.extend(self)
      ext.class_eval(&block)
      ext
    end

    def settings
      self
    end

    def configure(*args, &block)
      record(:configure, *args) { |c| c.instance_exec(c, &block) }
    end

    def registered(base = nil, &block)
      base ? replay(base) : record(:class_eval, &block)
    end

    private

    def record(method, *args, &block)
      recorded_methods << [method, args, block]
    end

    def replay(object)
      recorded_methods.each { |m, a, b| object.send(m, *a, &b) }
    end

    def recorded_methods
      @recorded_methods ||= []
    end

    def method_missing(method, *args, &block)
      return super unless Sinatra::Base.respond_to? method
      record(method, *args, &block)
      DontCall.new(method)
    end

    class DontCall < BasicObject
      def initialize(method) @method = method end
      def method_missing(*) fail "not supposed to use result of #@method!" end
      def inspect; "#<#{self.class}: #{@method}>" end
    end
  end
end
