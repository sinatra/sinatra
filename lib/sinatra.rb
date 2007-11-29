require 'rubygems'

if ENV['SWIFT']
 require 'swiftcore/swiftiplied_mongrel'
 puts "Using Swiftiplied Mongrel"
elsif ENV['EVENT']
  require 'swiftcore/evented_mongrel' 
  puts "Using Evented Mongrel"
end

require 'rack'
require 'ostruct'

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
  
  def port
    application.options.port
  end
  
  def env
    application.options.env
  end
  
  def run
    
    begin
      puts "== Sinatra has taken the stage on port #{port} for #{env}"
      require 'pp'
      Rack::Handler::Mongrel.run(Sinatra.application, :Port => port) do |server|
        trap(:INT) do
          server.stop
          puts "\n== Sinatra has ended his set (crowd applauds)"
        end
      end
    rescue Errno::EADDRINUSE => e
      puts "== Someone is already performing on port #{port}!"
    end
    
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
        throw :halt, Redirect.new(path)
      end

    end
    include ResponseHelpers
    
    module RenderingHelpers
      
      def render(content, options={})
        template = resolve_template(content, options)
        @content = _evaluate_render(template)
        layout = resolve_layout(options[:layout], options)
        @content = _evaluate_render(layout) if layout
        @content
      end
      
      private
        
        def _evaluate_render(content, options={})
          case content
          when String
            instance_eval(%Q{"#{content}"})
          when Proc
            instance_eval(&content)
          when File
            instance_eval(%Q{"#{content.read}"})
          end
        end
        
        def resolve_template(content, options={})
          case content
          when String
            content
          when Symbol
            File.new(filename_for(content, options))
          end
        end
      
        def resolve_layout(name, options={})
          return if name == false
          if layout = layouts[name || :layout]
            return layout
          end
          if File.file?(filename = filename_for(name, options))
            File.new(filename)
          end
        end
        
        def filename_for(name, options={})
          (options[:views_directory] || 'views') + "/#{name}.#{ext}"
        end
                
        def ext
          :html
        end

        def layouts
          Sinatra.application.layouts
        end
      
    end
    include RenderingHelpers
    
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
    
    def stop(content)
      throw :halt, content
    end
    
    def complete(returned)
      @response.body || returned
    end
    
    private

      def method_missing(name, *args, &b)
        @response.send(name, *args, &b)
      end
    
  end
  
  class Redirect
    def initialize(path)
      @path = path
    end
    
    def to_result(cx, *args)
      cx.status(302)
      cx.header.merge!('Location' => @path)
      cx.body = ''
    end
  end
    
  class Application
    
    attr_reader :events, :layouts
    
    def initialize
      @events = Hash.new { |hash, key| hash[key] = [] }
      @layouts = Hash.new
    end
    
    def define_event(method, path, &b)
      events[method] << event = Event.new(path, &b)
      event
    end
    
    def define_layout(name=:layout, &b)
      layouts[name] = b
    end
    
    def lookup(env)
      events[env['REQUEST_METHOD'].downcase.to_sym].eject(&[:invoke, env])
    end
    
    def options
      OpenStruct.new(
        :port => 4567,
        :env => :development
      )
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

def layout(name = :layout, &b)
  Sinatra.application.define_layout(name, &b)
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
    cx.body = self
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

class NilClass
  def to_result(cx, *args)
    cx.body = ''
    # log warning here
  end
end

at_exit do
  Sinatra.run
end
