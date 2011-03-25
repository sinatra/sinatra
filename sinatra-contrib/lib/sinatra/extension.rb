require 'sinatra/base'
require 'backports/basic_object' unless defined? BasicObject

module Sinatra
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
