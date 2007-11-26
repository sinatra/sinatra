require "rubygems"

if ENV['SWIFT']
 require 'swiftcore/swiftiplied_mongrel'
 puts "Using Swiftiplied Mongrel"
elsif ENV['EVENT']
  require 'swiftcore/evented_mongrel' 
  puts "Using Evented Mongrel"
end

require "rack"

require File.dirname(__FILE__) + '/sinatra/mime_types'
require File.dirname(__FILE__) + '/sinatra/halt_results'
require File.dirname(__FILE__) + '/sinatra/logger'

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

  attr_accessor :logger

  def run
    
    begin
      puts "== Sinatra has taken the stage on port #{Sinatra.config[:port]} for #{Sinatra.config[:env]}"
      require 'pp'
      Rack::Handler::Mongrel.run(Sinatra, :Port => Sinatra.config[:port]) do |server|
        trap(:INT) do
          server.stop
          puts "\n== Sinatra has ended his set (crowd applauds)"
        end
      end
    rescue Errno::EADDRINUSE => e
      puts "== Someone is already performing on port #{Sinatra.config[:port]}!"
    end
    
  end

  class EventContext
    
    attr_reader :request, :response, :route_params
    
    def logger
      Sinatra.logger
    end
    
    def initialize(request, response, route_params)
      @request, @response, @route_params = 
        request, response, route_params
    end
    
    def params
      @params ||= request.params.merge(route_params).symbolize_keys
    end
    
    def complete(b)
      self.instance_eval(&b)
    end
    
    # redirect to another url It can be like /foo/bar
    # for redirecting within your same app. Or it can
    # be a fully qualified url to another site.
    def redirect(url)
      logger.info "Redirecting to: #{url}"
      status(302)
      headers.merge!('Location' => url)
      return ''
    end
    
    def method_missing(name, *args)
      if args.size == 1 && response.respond_to?("#{name}=")
        response.send("#{name}=", args.first)
      else
        response.send(name, *args)
      end
    end
    
  end

  def setup_logger
    self.logger = Sinatra::Logger.new(
      config[:root] + "/#{Sinatra.config[:env]}.log"
    )
  end
  
  def setup_default_events!
    error 500 do
      "<h2>#{$!.message}</h2>#{$!.backtrace.join("<br/>")}"
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
    unless @filters 
      @filters = Hash.new do |hash, key| 
        hash[key] = Hash.new { |hash, key| hash[key] = [] }
      end
    end
    @filters
  end
  
  def config
    @config ||= default_config.dup
  end
  
  def config=(c)
    @config = c
  end
  
  def development?
    config[:env] == :development
  end
  
  def default_config
    @default_config ||= {
      :run => true,
      :port => 4567,
      :raise_errors => false,
      :env => :development,
      :root => Dir.pwd,
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
    
    reload! if Sinatra.development?

    time = Time.now
    
    request = Rack::Request.new(env)

    if found = serve_static_file(request.path_info)
      log_request_and_response(time, request, Rack::Response.new(found))
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
      context = handle_with_filters(route.groups, context, &route.block)
      context.status ||= route.default_status
    rescue => e
      raise e if config[:raise_errors]
      route = Sinatra.routes[500]
      context.status 500
      context.body Array(context.instance_eval(&route.block))
    ensure
      log_request_and_response(time, request, response)
      logger.flush
    end
    
    context.finish
  end
    
  def define_route(verb, path, options = {}, &b)
    routes[verb] << route = Route.new(path, Array(options[:groups]), &b)
    route
  end
  
  def define_error(code, &b)
    routes[code] = Error.new(code, &b)
  end
  
  def define_filter(type, group, &b)
    filters[type][group] << b
  end
  
  def reset!
    self.config = nil
    routes.clear
    filters.clear
    setup_default_events!
  end
  
  def reload!
    reset!
    self.config[:reloading] = true
    load $0
    self.config[:reloading] = false
  end
  
  protected
  
    def log_request_and_response(time, request, response)
      now = Time.now

      # Common Log Format: http://httpd.apache.org/docs/1.3/logs.html#common
      # lilith.local - - [07/Aug/2006 23:58:02] "GET / HTTP/1.1" 500 -
      #             %{%s - %s [%s] "%s %s%s %s" %d %s\n} %
      logger.info %{%s - %s [%s] "%s %s%s %s" %d %s %0.4f\n} %
        [
          request.env["REMOTE_ADDR"] || "-",
          request.env["REMOTE_USER"] || "-",
          now.strftime("%d/%b/%Y %H:%M:%S"),
          request.env["REQUEST_METHOD"],
          request.env["PATH_INFO"],
          request.env["QUERY_STRING"].empty? ? 
            "" : 
            "?" + request.env["QUERY_STRING"],
          request.env["HTTP_VERSION"],
          response.status.to_s[0..3].to_i,
          (response.body.length.zero? ? "-" : response.body.length.to_s),
          now - time
        ]
    end

    def handle_with_filters(groups, cx, &b)
      caught = catch(:halt) do
        filters_for(:before, groups).each { |x| cx.instance_eval(&x) }
        [:complete, b]
      end
      caught = catch(:halt) do
        caught.to_result(cx)
      end
      result = caught.to_result(cx) if caught
      filters_for(:after, groups).each { |x| cx.instance_eval(&x) }
      cx.body Array(result.to_s)
      cx
    end
    
    def filters_for(type, groups)
      filters[type][:all] + groups.inject([]) do |m, g|
        m + filters[type][g]
      end
    end
  
  class Route
        
    URI_CHAR = '[^/?:,&#]'.freeze unless defined?(URI_CHAR)
    PARAM = /:(#{URI_CHAR}+)/.freeze unless defined?(PARAM)
    
    attr_reader :block, :path
    
    def initialize(path, groups = :all, &b)
      @path, @groups, @block = path, Array(groups), b
      @param_keys = []
      @struct = Struct.new(:path, :groups, :block, :params, :default_status)
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
      @struct.new(@path, @groups, @block, include_format(params), 200)
    end
    
    def include_format(h)
      h.delete(:format) unless h[:format]
      Sinatra.config[:default_params].merge(h)
    end
    
    def pretty_print(pp)
      pp.text "{Route: #{@pattern} : [#{@param_keys.map(&:inspect).join(",")}] : #{@groups.join(",")} }"
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
    
    def groups; []; end
  end
      
end

def get(*paths, &b)
  options = Hash === paths.last ? paths.pop : {}
  paths.map { |path| Sinatra.define_route(:get, path, options, &b) }
end

def post(*paths, &b)
  options = Hash === paths.last ? paths.pop : {}
  paths.map { |path| Sinatra.define_route(:post, path, options, &b) }
end

def put(*paths, &b)
  options = Hash === paths.last ? paths.pop : {}
  paths.map { |path| Sinatra.define_route(:put, path, options, &b) }
end

def delete(*paths, &b)
  options = Hash === paths.last ? paths.pop : {}
  paths.map { |path| Sinatra.define_route(:delete, path, options, &b) }
end

def error(*codes, &b)
  raise 'You must specify a block to assciate with an error' if b.nil?
  codes.each { |code| Sinatra.define_error(code, &b) }
end

def before(*groups, &b)
  groups = [:all] if groups.empty?
  groups.each { |group| Sinatra.define_filter(:before, group, &b) }
end

def after(*groups, &b)
  groups = [:all] if groups.empty?
  groups.each { |group| Sinatra.define_filter(:after, group, &b) }
end

def mime_type(content_type, *exts)
  exts.each { |ext| Sinatra::MIME_TYPES.merge(ext.to_s, content_type) }
end

def helpers(&b)
  Sinatra::EventContext.class_eval(&b)
end

def configures(*envs)
  return if Sinatra.config[:reloading]
  yield if (envs.include?(Sinatra.config[:env]) || envs.empty?)
end
alias :configure :configures

Sinatra.setup_default_events!

at_exit do
  raise $! if $!
  Sinatra.setup_logger
  Sinatra.run if Sinatra.config[:run]
end