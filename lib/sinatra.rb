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

  class NotFound < RuntimeError; end
  class ServerError < RuntimeError; end

  Result = Struct.new(:block, :params, :status) unless defined?(Result)
  
  def application
    unless @app 
      @app = Application.new
      Sinatra::Environment.setup!
    end
    @app
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
  
  # Adapted from actionpack
  # Methods for sending files and streams to the browser instead of rendering.
  module Streaming
    DEFAULT_SEND_FILE_OPTIONS = {
      :type         => 'application/octet-stream'.freeze,
      :disposition  => 'attachment'.freeze,
      :stream       => true, 
      :buffer_size  => 4096
    }.freeze

    class FileStreamer
      
      attr_reader :path, :options
      
      def initialize(path, options)
        @path, @options = path, options
      end
      
      def to_result(cx)
        cx.body = self
      end
      
      def each
        File.open(path, 'rb') do |file|
          while buf = file.read(options[:buffer_size])
            yield buf
          end
        end
      end
      
    end

    protected
      # Sends the file by streaming it 4096 bytes at a time. This way the
      # whole file doesn't need to be read into memory at once.  This makes
      # it feasible to send even large files.
      #
      # Be careful to sanitize the path parameter if it coming from a web
      # page.  send_file(params[:path]) allows a malicious user to
      # download any file on your server.
      #
      # Options:
      # * <tt>:filename</tt> - suggests a filename for the browser to use.
      #   Defaults to File.basename(path).
      # * <tt>:type</tt> - specifies an HTTP content type.
      #   Defaults to 'application/octet-stream'.
      # * <tt>:disposition</tt> - specifies whether the file will be shown inline or downloaded.  
      #   Valid values are 'inline' and 'attachment' (default).
      # * <tt>:stream</tt> - whether to send the file to the user agent as it is read (true)
      #   or to read the entire file before sending (false). Defaults to true.
      # * <tt>:buffer_size</tt> - specifies size (in bytes) of the buffer used to stream the file.
      #   Defaults to 4096.
      # * <tt>:status</tt> - specifies the status code to send with the response. Defaults to '200 OK'.
      #
      # The default Content-Type and Content-Disposition headers are
      # set to download arbitrary binary files in as many browsers as
      # possible.  IE versions 4, 5, 5.5, and 6 are all known to have
      # a variety of quirks (especially when downloading over SSL).
      #
      # Simple download:
      #   send_file '/path/to.zip'
      #
      # Show a JPEG in the browser:
      #   send_file '/path/to.jpeg', :type => 'image/jpeg', :disposition => 'inline'
      #
      # Show a 404 page in the browser:
      #   send_file '/path/to/404.html, :type => 'text/html; charset=utf-8', :status => 404
      #
      # Read about the other Content-* HTTP headers if you'd like to
      # provide the user with more information (such as Content-Description).
      # http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.11
      #
      # Also be aware that the document may be cached by proxies and browsers.
      # The Pragma and Cache-Control headers declare how the file may be cached
      # by intermediaries.  They default to require clients to validate with
      # the server before releasing cached responses.  See
      # http://www.mnot.net/cache_docs/ for an overview of web caching and
      # http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.9
      # for the Cache-Control header spec.
      def send_file(path, options = {}) #:doc:
        raise MissingFile, "Cannot read file #{path}" unless File.file?(path) and File.readable?(path)

        options[:length]   ||= File.size(path)
        options[:filename] ||= File.basename(path)
        options[:type] ||= Rack::File::MIME_TYPES[File.extname(options[:filename])[1..-1]] || 'text/plain'
        send_file_headers! options

        if options[:stream]
          throw :halt, [options[:status] || 200, FileStreamer.new(path, options)]
        else
          File.open(path, 'rb') { |file| throw :halt, [options[:status] || 200, file.read] }
        end
      end

      # Send binary data to the user as a file download.  May set content type, apparent file name,
      # and specify whether to show data inline or download as an attachment.
      #
      # Options:
      # * <tt>:filename</tt> - Suggests a filename for the browser to use.
      # * <tt>:type</tt> - specifies an HTTP content type.
      #   Defaults to 'application/octet-stream'.
      # * <tt>:disposition</tt> - specifies whether the file will be shown inline or downloaded.  
      #   Valid values are 'inline' and 'attachment' (default).
      # * <tt>:status</tt> - specifies the status code to send with the response. Defaults to '200 OK'.
      #
      # Generic data download:
      #   send_data buffer
      #
      # Download a dynamically-generated tarball:
      #   send_data generate_tgz('dir'), :filename => 'dir.tgz'
      #
      # Display an image Active Record in the browser:
      #   send_data image.data, :type => image.content_type, :disposition => 'inline'
      #
      # See +send_file+ for more information on HTTP Content-* headers and caching.
      def send_data(data, options = {}) #:doc:
        send_file_headers! options.merge(:length => data.size)
        throw :halt, [options[:status] || 200, data]
      end

    private
      def send_file_headers!(options)
        options.update(DEFAULT_SEND_FILE_OPTIONS.merge(options))
        [:length, :type, :disposition].each do |arg|
          raise ArgumentError, ":#{arg} option required" if options[arg].nil?
        end

        disposition = options[:disposition].dup || 'attachment'

        disposition <<= %(; filename="#{options[:filename]}") if options[:filename]

        headers(
          'Content-Length'            => options[:length].to_s,
          'Content-Type'              => options[:type].strip,  # fixes a problem with extra '\r' with some browsers
          'Content-Disposition'       => disposition,
          'Content-Transfer-Encoding' => 'binary'
        )

        # Fix a problem with IE 6.0 on opening downloaded files:
        # If Cache-Control: no-cache is set (which Rails does by default), 
        # IE removes the file it just downloaded from its cache immediately 
        # after it displays the "open/save" dialog, which means that if you 
        # hit "open" the file isn't there anymore when the application that 
        # is called for handling the download is run, so let's workaround that
        header('Cache-Control' => 'private') if headers['Cache-Control'] == 'no-cache'
      end
  end
  
  module ResponseHelpers

    def redirect(path, *args)
      status(302)
      headers 'Location' => path
      throw :halt, *args
    end
    
    def headers(header = nil)
      @response.headers.merge!(header) if header
      @response.headers
    end
    alias :header :headers

  end
  
  module RenderingHelpers

    def render(renderer, template, options={})
      m = method("render_#{renderer}")
      result = m.call(resolve_template(renderer, template, options))
      if layout = determine_layout(renderer, template, options)
        result = m.call(resolve_template(renderer, layout, options)) { result }
      end
      result
    end
    
    def determine_layout(renderer, template, options)
      layout_from_options = options[:layout] || :layout
      layout = layouts[layout_from_options]
      layout ||= resolve_template(renderer, layout_from_options, options, false)
      layout
    end

    private
        
      def resolve_template(renderer, template, options, scream = true)
        case template
        when String
          template
        when Proc
          template.call
        when Symbol
          path = File.join(
            options[:views_directory] || Sinatra.application.options.views,
            "#{template}.#{renderer}"
          )
          unless File.exists?(path)
            raise Errno::ENOENT.new(path) if scream
            nil
          else  
            File.read(path)
          end
        else
          nil
        end
      end
      
      def layouts
        Sinatra.application.layouts
      end
    
  end

  module Erb
    
    def erb(content, options={})
      require 'erb'
      render(:erb, content, options)
    end
    
    private 
    
      def render_erb(content)
        ::ERB.new(content).result(binding)
      end
      
  end

  module Haml
    
    def haml(content, options={})
      require 'haml'
      render(:haml, content, options)
    end
    
    private
    
      def render_haml(content, &b)
        ::Haml::Engine.new(content).render(self, &b)
      end
        
  end
  
  class EventContext
    
    include ResponseHelpers
    include Streaming
    include RenderingHelpers
    include Erb
    include Haml
    
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
    
    attr_reader :events, :errors, :layouts, :default_options, :filters, :clearables, :reloading
    attr_writer :options
    
    def self.default_options
      @@default_options ||= {
        :run => true,
        :port => 4567,
        :env => :development,
        :root => Dir.pwd,
        :views => Dir.pwd + '/views',
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
      @clearables = [
        @events = Hash.new { |hash, key| hash[key] = [] },
        @errors = Hash.new,
        @filters = Hash.new { |hash, key| hash[key] = [] },
        @layouts = Hash.new
      ]
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
      e ||= (errors[NotFound]).invoke(env)
      e
    end

    def options
      @options ||= OpenStruct.new(default_options)
    end
    
    def development?
      options.env == :development
    end

    def reload!
      @reloading = true
      clearables.each(&:clear)
      Kernel.load $0
      @reloading = false
      Environment.setup!
    end
        
    def call(env)
      reload! if development?
      result = lookup(env)
      context = EventContext.new(
        Rack::Request.new(env), 
        Rack::Response.new,
        result.params
      )
      context.status(result.status)
      begin
        returned = catch(:halt) do
          filters[:before].each { |f| context.instance_eval(&f) }
          [:complete, context.instance_eval(&result.block)]
        end
        body = returned.to_result(context)
      rescue => e
        raise e if options.raise_errors
        env['sinatra.error'] = e
        context.status(500)
        result = (errors[e.class] || errors[ServerError]).invoke(env)
        returned = catch(:halt) do
          [:complete, context.instance_eval(&result.block)]
        end
        body = returned.to_result(context)
      end
      body = '' unless body.respond_to?(:each)
      context.body = body.kind_of?(String) ? [*body] : body
      context.finish
    end
    
  end
  
  
  module Environment
    extend self
    
    def setup!
      configure do
        error { '<h1>Internal Server Error</h1>'}
        not_found { '<h1>Not Found</h1>'}
      end
      
      configures :development do

        get '/sinatra_custom_images/:image.png' do
          File.read(File.dirname(__FILE__) + "/../images/#{params[:image]}.png")
        end

        not_found do
          %Q(
          <html>
            <body style='text-align: center; color: #888; font-family: Arial; font-size: 22px; margin: 20px'>
            <h2>Sinatra doesn't know this diddy.</h2>
            <img src='/sinatra_custom_images/404.png'></img>
            </body>
          </html>
          )
        end

        error do
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

def error(type = Sinatra::ServerError, options = {}, &b)
  Sinatra.application.define_error(type, options, &b)
end

def not_found(options = {}, &b)
  Sinatra.application.define_error(Sinatra::NotFound, options, &b)
end

def layout(name = :layout, &b)
  Sinatra.application.define_layout(name, &b)
end

def configures(*envs, &b)
  yield if  !Sinatra.application.reloading && 
            (envs.include?(Sinatra.application.options.env) ||
            envs.empty?)
end
alias :configure :configures

def mime(ext, type)
  Rack::File::MIME_TYPES[ext.to_s] = type
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
  raise $! if $!
  if Sinatra.application.options.run
    Sinatra.run 
  end
end

mime :xml,  'application/xml'
mime :js,  'application/javascript'
