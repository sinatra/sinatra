require "rubygems"
require "rack"

require 'sinatra/mime_types'
require 'sinatra/send_file_mixin'
require 'sinatra/halt_results'

def silence_warnings
  old_verbose, $VERBOSE = $VERBOSE, nil
  yield
ensure
  $VERBOSE = old_verbose
end

class String
  def to_param
    URI.escape(self)
  end
  
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
    Proc.new { |*args| args.shift.__send__(self[0], args + self[1..-1]) }
  end
end

class Proc
  def block
    self
  end
end

module Enumerable
  def eject(&block)
    find { |e| result = block[e] and break result }
  end
end

module Sinatra
  extend self

  EventContext = Struct.new(:request, :response, :route_params) do
    def params
      @params ||= request.params.merge(route_params).symbolize_keys
    end
    
    def complete(b)
      self.instance_eval(&b)
    end
    
    def method_missing(name, *args)
      if args.size == 1 && response.respond_to?("#{name}=")
        response.send("#{name}=", args.first)
      else
        response.send(name, *args)
      end
    end
  end
  
  def setup_default_events!
    error 500 do
      "#{$!.message}\n\t#{$!.backtrace.join("\n\t")}"
    end

    error 404 do
      "<h1>Not Found</h1>"
    end
  end
  
  def request_types
    @request_types ||= [:get, :put, :post, :delete]
  end
  
  def routes
    @routes ||= Hash.new do |hash, key|
      hash[key] = [] if request_types.include?(key)
    end
  end
  
  def filters
    @filters ||= Hash.new { |hash, key| hash[key] = [] }
  end
  
  def config
    @config ||= @default_config.dup
  end
  
  def config=(c)
    @config = c
  end
  
  def default_config
    @default_config ||= {
      :run => true,
      :raise_errors => false,
      :env => :development,
      :root => File.dirname($0),
      :default_static_mime_type => 'text/plain',
      :default_params => { :format => 'html' }
    }
  end
  
  def determine_route(verb, path)
    routes[verb].eject { |r| r.match(path) } || routes[404]
  end
  
  def content_type_for(path)
    ext = File.extname(path)[1..-1]
    Sinatra.mime_types[ext] || config[:default_static_mime_type]
  end
  
  def serve_static_file(path)
    path = Sinatra.config[:root] + '/public' + path
    if File.file?(path)
      headers = {
        'Content-Type' => Array(content_type_for(path)),
        'Content-Length' => Array(File.size(path))
      }
      [200, headers, File.read(path)]
    end
  end
  
  def call(env)
    request = Rack::Request.new(env)

    if found = serve_static_file(request.path_info)
      return found
    end
        
    response = Rack::Response.new
    route = determine_route(
      request.request_method.downcase.to_sym, 
      request.path_info
    )
    context = EventContext.new(request, response, route.params)
    context.status = nil
    begin
      context = handle_with_filters(context, &route.block)
      context.status ||= route.default_status
      context.finish
    rescue => e
      raise e if config[:raise_errors]
      route = Sinatra.routes[500]
      context.status 500
      context.body Array(context.instance_eval(&route.block))
      context.finish
    end
  end
  
  def define_route(verb, path, &b)
    routes[verb] << route = Route.new(path, &b)
    route
  end
  
  def define_error(code, &b)
    routes[code] = Error.new(code, &b)
  end
  
  def define_filter(type, &b)
    filters[type] << b
  end
  
  def reset!
    routes.clear
    config = nil
    setup_default_events!
  end
  
  protected

    def handle_with_filters(cx, &b)
      caught = catch(:halt) do
        filters[:before].each { |x| cx.instance_eval(&x) }
        [:complete, b]
      end
      caught = catch(:halt) do
        caught.to_result(cx)
      end
      result = caught.to_result(cx) if caught
      filters[:after].each { |x| cx.instance_eval(&x) }
      cx.body Array(result.to_s)
      cx
    end
  
  class Route
        
    URI_CHAR = '[^/?:,&#]'.freeze unless defined?(URI_CHAR)
    PARAM = /:(#{URI_CHAR}+)/.freeze unless defined?(PARAM)
    
    Result = Struct.new(:path, :block, :params, :default_status)
    
    attr_reader :block, :path
    
    def initialize(path, &b)
      @path, @block = path, b
      @param_keys = []
      regex = path.to_s.gsub(PARAM) do
        @param_keys << $1.intern
        "(#{URI_CHAR}+)"
      end
      if path =~ /:format$/
        @pattern = /^#{regex}$/
      else
        @param_keys << :format
        @pattern = /^#{regex}(?:\.(#{URI_CHAR}+))?$/
      end
    end
        
    def match(path)
      return nil unless path =~ @pattern
      params = @param_keys.zip($~.captures.compact.map(&:from_param)).to_hash
      Result.new(@path, @block, include_format(params), 200)
    end
    
    def include_format(h)
      h.delete(:format) unless h[:format]
      Sinatra.config[:default_params].merge(h)
    end
    
  end
  
  class Error
    
    attr_reader :block
    
    def initialize(code, &b)
      @code, @block = code, b
    end
    
    def default_status
      @code
    end
    
    def params; {}; end
  end
      
end

def get(*paths, &b)
  paths.map { |path| Sinatra.define_route(:get, path, &b) }
end

def error(*codes, &b)
  raise 'You must specify a block to assciate with an error' if b.nil?
  codes.each { |code| Sinatra.define_error(code, &b) }
end

def before(&b)
  Sinatra.define_filter(:before, &b)
end

def after(&b)
  Sinatra.define_filter(:after, &b)
end

def mime_type(content_type, *exts)
  exts.each { |ext| Sinatra::MIME_TYPES.merge(ext.to_s, content_type) }
end

def helpers(&b)
  Sinatra::EventContext.class_eval(&b)
end

Sinatra.setup_default_events!

Sinatra::EventContext.send :include, Sinatra::SendFileMixin


