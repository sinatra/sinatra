require 'rubygems'
require 'rack'

module Sinatra

  Result = Struct.new(:block, :params)
  
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
    
    attr_accessor :request, :response
    
    def initialize(request, response, route_params)
      @request = request
      @response = response
      @route_params = route_params
      @response.body = nil
    end
    
    def params
      @params ||= @route_params.merge(@request.params).symbolize_keys
    end
    
    def method_missing(name, *args, &b)
      @response.send(name, *args, &b)
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
      returned = context.instance_eval(&result.block)
      context.body ||= returned
      context.finish
    end
    
  end
  
end

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
