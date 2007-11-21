require "rubygems"
require "rack"

class String
  def to_param
    URI.escape(self)
  end
  
  def from_param
    URI.unescape(self)
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
    Proc.new { |*args| args.shift.send(self[0], args + self[1..-1]) }
  end
end


module Enumerable
  def eject(&block)
    find { |e| result = block[e] and break result }
  end
end


module Sinatra
  extend self
  
  def request_types
    @request_types ||= [:get, :put, :post, :delete]
  end
  
  def routes
    @routes ||= Hash.new do |hash, key|
      hash[key] = [] if request_types.include?(key)
    end
  end
  
  def determine_event(verb, path)
    routes[verb].eject { |r| r.match(path) }
  end
  
  class Route
    
    URI_CHAR = '[^/?:,&#]'.freeze unless defined?(URI_CHAR)
    PARAM = /:(#{URI_CHAR}+)/.freeze unless defined?(PARAM)
    
    attr_reader :block, :path
    
    def initialize(path, &b)
      @path, @block = path, b
      @param_keys = []
      regex = path.to_s.gsub(PARAM) do
        @param_keys << $1.intern
        "(#{URI_CHAR}+)"
      end
      @pattern = /^#{regex}$/
      @struct = Struct.new(:block, :params)
    end
    
    def match(path)
      return nil unless path =~ @pattern
      params = @param_keys.zip($~.captures.map(&:from_param)).to_hash
      @struct.new(@block, params)
    end
    
  end
  
end


