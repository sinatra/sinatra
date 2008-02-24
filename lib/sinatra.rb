require 'rubygems'
require 'metaid'

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

  Result = Struct.new(:block, :params, :status) unless defined?(Result)
  
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
  
  def build_application
    Rack::CommonLogger.new(application)
  end
  
  def run
    
    begin
      puts "== Sinatra has taken the stage on port #{port} for #{env}"
      require 'pp'
      Rack::Handler::Mongrel.run(build_application, :Port => port) do |server|
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

    URI_CHAR = '[^/?:,&#\.]'.freeze unless defined?(URI_CHAR)
    PARAM = /:(#{URI_CHAR}+)/.freeze unless defined?(PARAM)
    SPLAT = /(.*?)/
    attr_reader :path, :block, :param_keys, :pattern, :options
    
    def initialize(path, options = {}, &b)
      @path = path
      @block = b
      @param_keys = []
      @options = options
      regex = @path.to_s.gsub(PARAM) do
        @param_keys << $1.intern
        "(#{URI_CHAR}+)"
      end
      
      regex.gsub!('*', SPLAT.to_s)
      
      @pattern = /^#{regex}$/
    end
        
    def invoke(env)
      if options[:agent] 
        return unless env['HTTP_USER_AGENT'] =~ options[:agent]
      end
      return unless pattern =~ env['PATH_INFO'].squeeze('/')
      params = param_keys.zip($~.captures.map(&:from_param)).to_hash
      Result.new(block, params, 200)
    end
    
  end
  
  class Error
    
    attr_reader :code, :block
    
    def initialize(code, &b)
      @code, @block = code, b
    end
    
    def invoke(env)
      Result.new(block, {}, 404)
    end
    
  end
  
  class Static
            
    def invoke(env)
      return unless File.file?(
        Sinatra.application.options.public + env['PATH_INFO']
      )
      Result.new(block, {}, 200)
    end
    
    def block
      Proc.new do
        send_file Sinatra.application.options.public + 
          request.env['PATH_INFO']
      end
    end
    
  end
  
  module ResponseHelpers

    def redirect(path, *args)
      status(302)
      headers 'Location' => path
      throw :halt, *args
    end
    
    def send_file(filename)
      throw :halt, File.read(filename)
    end

    def headers(header = nil)
      @response.headers.merge!(header) if header
      @response.headers
    end
    alias :header :headers

  end
  
  module RenderingHelpers
    
    def text(content, options={})
      render(content, options.merge(:renderer => :text, :ext => :html))
    end

    def erb(content, options={})
      render(content, options.merge(:renderer => :erb, :ext => :erb))
    end

    def render(content, options={})
      options[:layout] ||= :layout
      template = resolve_template(content, options)
      @content = evaluate_renderer(template, options)
      layout = resolve_layout(options[:layout], options)
      @content = evaluate_renderer(layout, options) if layout
      @content
    end
    
    private
      
      def evaluate_text(content, options={})
        instance_eval(%Q{"#{content}"})
      end
      
      def evaluate_erb(content, options={})
        require 'erb'
        ERB.new(content).result(binding)
      end
      
      def evaluate_renderer(content, options={})
        renderer = "evaluate_#{options[:renderer] || :text}"
        result = case content
        when String
          content
        when Proc
          content.call
        when File
          content.read
        end
        send(renderer, result, options)
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
        (options[:views_directory] || 'views') + "/#{name}.#{options[:ext]}"
      end

      def layouts
        Sinatra.application.layouts
      end
    
  end

  class EventContext
    
    include ResponseHelpers
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
  
  class Application
    
    attr_reader :events, :errors, :layouts, :default_options, :filters
    attr_writer :options
    
    def self.default_options
      @@default_options ||= {
        :run => true,
        :port => 4567,
        :env => :development,
        :root => Dir.pwd,
        :public => Dir.pwd + '/public'
      }
    end
    
    def default_options
      self.class.default_options
    end

    def load_options!
      require 'optparse'
      OptionParser.new do |op|
        op.on('-p port') { |port| default_options[:port] = port }
        op.on('-e env') { |env| default_options[:env] = env }
      end.parse!(ARGV.dup.select { |o| o !~ /--name/ })
    end
        
    def initialize
      @events = Hash.new { |hash, key| hash[key] = [] }
      @errors = Hash.new
      @filters = Hash.new { |hash, key| hash[key] = [] }
      @layouts = Hash.new
      load_options!
    end
    
    def define_event(method, path, options = {}, &b)
      events[method] << event = Event.new(path, options, &b)
      event
    end
    
    def define_layout(name=:layout, &b)
      layouts[name] = b
    end
    
    def define_error(code, options = {}, &b)
      errors[code] = Error.new(code, &b)
    end
    
    def define_filter(type, &b)
      filters[:before] << b
    end
    
    def static
      @static ||= Static.new
    end
    
    def lookup(env)
      method = env['REQUEST_METHOD'].downcase.to_sym
      e = static.invoke(env) 
      e ||= events[method].eject(&[:invoke, env])
      e ||= (errors[404] || basic_not_found).invoke(env)
      e
    end
    
    def basic_not_found
      Error.new(404) do
        '<h1>Not Found</h1>'
      end
    end
    
    def basic_error
      Error.new(500) do
        '<h1>Internal Server Error</h1>'
      end
    end

    def options
      @options ||= OpenStruct.new(default_options)
    end
        
    def call(env)
      result = lookup(env)
      context = EventContext.new(
        Rack::Request.new(env), 
        Rack::Response.new,
        result.params
      )
      begin
        context.status(result.status)
        returned = catch(:halt) do
          filters[:before].each { |f| context.instance_eval(&f) }
          [:complete, context.instance_eval(&result.block)]
        end
        body = returned.to_result(context)
        body = '' unless body.respond_to?(:each)
        context.body = body.kind_of?(String) ? [*body] : body
        context.finish
      rescue => e
        raise e if options.raise_errors
        env['sinatra.error'] = e
        context.status(500)
        result = (errors[e.class] || errors[500] || basic_error).invoke(env)
        returned = catch(:halt) do
          [:complete, context.instance_eval(&result.block)]
        end
        body = returned.to_result(context)
        body = '' unless body.respond_to?(:each)
        context.body = body.kind_of?(String) ? [*body] : body
        context.finish
      end
    end
    
  end
  
end

def get(path, options ={}, &b)
  Sinatra.application.define_event(:get, path, options, &b)
end

def post(path, options ={}, &b)
  Sinatra.application.define_event(:post, path, options, &b)
end

def put(path, options ={}, &b)
  Sinatra.application.define_event(:put, path, options, &b)
end

def delete(path, options ={}, &b)
  Sinatra.application.define_event(:delete, path, options, &b)
end

def before(&b)
  Sinatra.application.define_filter(:before, &b)
end

def helpers(&b)
  Sinatra::EventContext.class_eval(&b)
end

def error(code, options = {}, &b)
  Sinatra.application.define_error(code, options, &b)
end

def layout(name = :layout, &b)
  Sinatra.application.define_layout(name, &b)
end

def configures(*envs, &b)
  yield if  envs.include?(Sinatra.application.options.env) ||
            envs.empty?
end
alias :configure :configures

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
  raise $! if $!
  Sinatra.run if Sinatra.application.options.run
end

configures :development do
  
  get '/sinatra_custom_images/:image.png' do
    File.read(File.dirname(__FILE__) + "/../images/#{params[:image]}.png")
  end
  
  error 404 do
    %Q(
    <html>
      <body style='text-align: center; color: #888; font-family: Arial; font-size: 22px; margin: 20px'>
      <h2>Sinatra doesn't know this diddy.</h2>
      <img src='/sinatra_custom_images/404.png'></img>
      </body>
    </html>
    )
  end
  
  error 500 do
    @error = request.env['sinatra.error']
    %Q(
    <html>
    	<body>
    		<style type="text/css" media="screen">
    			body {
    				font-family: Verdana;
    				color: #333;
    			}

    			#content {
    				width: 700px;
    				margin-left: 20px;
    			}

    			#content h1 {
    				width: 99%;
    				color: #1D6B8D;
    				font-weight: bold;
    			}
    			
    			#stacktrace {
    			  margin-top: -20px;
    			}

    			#stacktrace pre {
    				font-size: 12px;
    				border-left: 2px solid #ddd;
    				padding-left: 10px;
    			}

    			#stacktrace img {
    				margin-top: 10px;
    			}
    		</style>
    		<div id="content">
      		<img src="/sinatra_custom_images/500.png" />
    			<div id="stacktrace">
    				<h1>#{@error.message}</h1>
    				<pre><code>#{@error.backtrace.join("\n")}</code></pre>
    		</div>
    	</body>
    </html>
    )
  end
  
end
