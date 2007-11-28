require 'rubygems'
require 'rack'

class Class
  def dslify_writter(*syms)
    syms.each do |sym|
      class_eval <<-end_eval
        def #{sym}(v=nil)
          self.send "#{sym}=", v if v
          v
        end
      end_eval
    end
  end
end

module Sinatra
  extend self

  Result = Struct.new(:block, :params)
  
  def application
    @app ||= Application.new
  end
  
  def application=(app)
    @app = app
  end
      
  class Event

    URI_CHAR = '[^/?:,&#]'.freeze unless defined?(URI_CHAR)
    PARAM = /:(#{URI_CHAR}+)/.freeze unless defined?(PARAM)
    
    attr_reader :path, :block, :param_keys, :pattern
    
    def initialize(path, &b)
      @path = path
      @block = b
      @param_keys = []
      regex = @path.to_s.gsub(PARAM) do
        @param_keys << $1.intern
        "(#{URI_CHAR}+)"
      end
      @pattern = /^#{regex}$/
    end
        
    def invoke(env)
      return unless pattern =~ env['PATH_INFO'].squeeze('/')
      params = param_keys.zip($~.captures.map(&:from_param)).to_hash
      Result.new(block, params)
    end
    
  end
  
  class EventContext
    
    module ResponseHelpers

      def redirect(path)
        throw :halt, NotFound.new(path)
      end

    end
    
    include ResponseHelpers
    
    attr_accessor :request, :response
    
    dslify_writter :status, :body
    
    def initialize(request, response, route_params)
      @request = request
      @response = response
      @route_params = route_params
      @response.body = nil
    end
    
    def params
      @params ||= @route_params.merge(@request.params).symbolize_keys
    end
    
    def complete(returned)
      @response.body ||= returned
    end
    
    def method_missing(name, *args, &b)
      @response.send(name, *args, &b)
    end
    
  end
  
  class NotFound
    def initialize(path)
      @path = path
    end
    
    def to_result(cx, *args)
      cx.status(302)
      cx.header.merge!('Location' => @path)
      cx.body('')
    end
  end
  
  class Application
    
    attr_reader :events
    
    def initialize
      @events = Hash.new { |hash, key| hash[key] = [] }
    end
    
    def define_event(method, path, &b)
      events[method] << event = Event.new(path, &b)
      event
    end
    
    def lookup(env)
      events[env['REQUEST_METHOD'].downcase.to_sym].eject(&[:invoke, env])
    end
    
    def call(env)
      return [404, {}, 'Not Found'] unless result = lookup(env)
      context = EventContext.new(
        Rack::Request.new(env), 
        Rack::Response.new,
        result.params
      )
      returned = catch(:halt) do
        [:complete, context.instance_eval(&result.block)]
      end
      result = returned.to_result(context)
      context.body = String === result ? [*result] : result
      context.finish
    end
        
  end
  
end

def get(path, &b)
  Sinatra.application.define_event(:get, path, &b)
end

def post(path, &b)
  Sinatra.application.define_event(:post, path, &b)
end

def put(path, &b)
  Sinatra.application.define_event(:put, path, &b)
end

def delete(path, &b)
  Sinatra.application.define_event(:delete, path, &b)
end

def helpers(&b)
  Sinatra::EventContext.class_eval(&b)
end

### Misc Core Extensions

module Kernel

  def silence_warnings
    old_verbose, $VERBOSE = $VERBOSE, nil
    yield
  ensure
    $VERBOSE = old_verbose
  end

end

class String

  # Converts +self+ to an escaped URI parameter value
  #   'Foo Bar'.to_param # => 'Foo%20Bar'
  def to_param
    URI.escape(self)
  end
  
  # Converts +self+ from an escaped URI parameter value
  #   'Foo%20Bar'.from_param # => 'Foo Bar'
  def from_param
    URI.unescape(self)
  end
  
end

class Hash
  
  def to_params
    map { |k,v| "#{k}=#{URI.escape(v)}" }.join('&')
  end
  
  def symbolize_keys
    self.inject({}) { |h,(k,v)| h[k.to_sym] = v; h }
  end
  
  def pass(*keys)
    reject { |k,v| !keys.include?(k) }
  end
  
end

class Symbol
  
  def to_proc 
    Proc.new { |*args| args.shift.__send__(self, *args) }
  end
  
end

class Array
  
  def to_hash
    self.inject({}) { |h, (k, v)|  h[k] = v; h }
  end
  
  def to_proc
    Proc.new { |*args| args.shift.__send__(self[0], *(args + self[1..-1])) }
  end
  
end

module Enumerable
  
  def eject(&block)
    find { |e| result = block[e] and break result }
  end
  
end

### Core Extension results for throw :halt

class Proc
  def to_result(cx, *args)
    cx.instance_eval(&self)
  end
end

class String
  def to_result(cx, *args)
    cx.body self
  end
end

class Array
  def to_result(cx, *args)
    self.shift.to_result(cx, *self)
  end
end

class Symbol
  def to_result(cx, *args)
    cx.send(self, *args)
  end
end

class Fixnum
  def to_result(cx, *args)
    cx.status self
    cx.body args.first
  end
end
