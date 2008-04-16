Dir[File.dirname(__FILE__) + "/../vendor/*"].each do |l|
  $:.unshift "#{File.expand_path(l)}/lib"
end

require 'rack'

require 'rubygems'
require 'uri'
require 'time'
require 'ostruct'

if ENV['SWIFT']
 require 'swiftcore/swiftiplied_mongrel'
 puts "Using Swiftiplied Mongrel"
elsif ENV['EVENT']
  require 'swiftcore/evented_mongrel' 
  puts "Using Evented Mongrel"
end

class Class
  def dslify_writer(*syms)
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

module Rack #:nodoc:
  
  class Request #:nodoc:

    # Set of request method names allowed via the _method parameter hack. By default,
    # all request methods defined in RFC2616 are included, with the exception of
    # TRACE and CONNECT.
    POST_TUNNEL_METHODS_ALLOWED = %w( PUT DELETE OPTIONS HEAD )

    # Return the HTTP request method with support for method tunneling using the POST
    # _method parameter hack.  If the real request method is POST and a _method param is
    # given and the value is one defined in +POST_TUNNEL_METHODS_ALLOWED+, return the value
    # of the _method param instead.
    def request_method
      if post_tunnel_method_hack?
        params['_method'].upcase
      else
        @env['REQUEST_METHOD']
      end
    end

    def user_agent
      env['HTTP_USER_AGENT']
    end

    private

      # Return truthfully if and only if the following conditions are met: 1.) the
      # *actual* request method is POST, 2.) the request content-type is one of
      # 'application/x-www-form-urlencoded' or 'multipart/form-data', 3.) there is a 
      # "_method" parameter in the POST body (not in the query string), and 4.) the 
      # method parameter is one of the verbs listed in the POST_TUNNEL_METHODS_ALLOWED
      # list.
      def post_tunnel_method_hack?
        @env['REQUEST_METHOD'] == 'POST' &&
          POST_TUNNEL_METHODS_ALLOWED.include?(self.POST.fetch('_method', '').upcase)
      end

  end
  
  module Utils
    extend self
  end

end

module Sinatra
  extend self

  module Version
    MAJOR = '0'
    MINOR = '2'
    REVISION = '1'
    def self.combined
      [MAJOR, MINOR, REVISION].join('.')
    end
  end

  class NotFound < RuntimeError; end
  class ServerError < RuntimeError; end

  Result = Struct.new(:block, :params, :status) unless defined?(Result)

  def options
    application.options
  end
  
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
    app = application
    app = Rack::Session::Cookie.new(app) if Sinatra.options.sessions == true
    app = Rack::CommonLogger.new(app) if Sinatra.options.logging == true
    app
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
      @path = URI.encode(path)
      @block = b
      @param_keys = []
      @options = options
      regex = @path.to_s.gsub(PARAM) do
        @param_keys << $1
        "(#{URI_CHAR}+)"
      end
      
      regex.gsub!('*', SPLAT.to_s)
      
      @pattern = /^#{regex}$/
    end
        
    def invoke(request)
      params = {}
      if agent = options[:agent] 
        return unless request.user_agent =~ agent
        params[:agent] = $~[1..-1]
      end
      if host = options[:host] 
        return unless host === request.host
      end
      return unless pattern =~ request.path_info.squeeze('/')
      params.merge!(param_keys.zip($~.captures.map(&:from_param)).to_hash)
      Result.new(block, params, 200)
    end
    
  end
  
  class Error
    
    attr_reader :code, :block
    
    def initialize(code, &b)
      @code, @block = code, b
    end
    
    def invoke(request)
      Result.new(block, {}, 404)
    end
    
  end
  
  class Static
            
    def invoke(request)
      return unless File.file?(
        Sinatra.application.options.public + request.path_info
      )
      Result.new(block, {}, 200)
    end
    
    def block
      Proc.new do
        send_file Sinatra.application.options.public + request.path_info,
          :disposition => nil
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

    class MissingFile < RuntimeError; end

    class FileStreamer
      
      attr_reader :path, :options
      
      def initialize(path, options)
        @path, @options = path, options
      end
      
      def to_result(cx, *args)
        self
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
      #   Valid values are 'inline' and 'attachment' (default). When set to nil, the
      #   Content-Disposition and Content-Transfer-Encoding headers are omitted entirely.
      # * <tt>:stream</tt> - whether to send the file to the user agent as it is read (true)
      #   or to read the entire file before sending (false). Defaults to true.
      # * <tt>:buffer_size</tt> - specifies size (in bytes) of the buffer used to stream the file.
      #   Defaults to 4096.
      # * <tt>:status</tt> - specifies the status code to send with the response. Defaults to '200 OK'.
      # * <tt>:last_modified</tt> - an optional RFC 2616 formatted date value (See Time#httpdate)
      #   indicating the last modified time of the file. If the request includes an
      #   If-Modified-Since header that matches this value exactly, a 304 Not Modified response
      #   is sent instead of the file. Defaults to the file's last modified
      #   time.
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
        options[:last_modified] ||= File.mtime(path).httpdate
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
      # * <tt>:last_modified</tt> - an optional RFC 2616 formatted date value (See Time#httpdate)
      #   indicating the last modified time of the response entity. If the request includes an
      #   If-Modified-Since header that matches this value exactly, a 304 Not Modified response
      #   is sent instead of the data.
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
        options = DEFAULT_SEND_FILE_OPTIONS.merge(options)
        [:length, :type, :disposition].each do |arg|
          raise ArgumentError, ":#{arg} option required" unless options.key?(arg)
        end

        # Send a "304 Not Modified" if the last_modified option is provided and matches
        # the If-Modified-Since request header value.
        if last_modified = options[:last_modified]
          header 'Last-Modified' => last_modified
          throw :halt, [ 304, '' ] if last_modified == request.env['HTTP_IF_MODIFIED_SINCE']
        end

        headers(
          'Content-Length'            => options[:length].to_s,
          'Content-Type'              => options[:type].strip  # fixes a problem with extra '\r' with some browsers
        )

        # Omit Content-Disposition and Content-Transfer-Encoding headers if
        # the :disposition option set to nil.
        if !options[:disposition].nil?
          disposition = options[:disposition].dup || 'attachment'
          disposition <<= %(; filename="#{options[:filename]}") if options[:filename]
          headers 'Content-Disposition' => disposition, 'Content-Transfer-Encoding' => 'binary'
        end

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
      result = m.call(resolve_template(renderer, template, options), options)
      if layout = determine_layout(renderer, template, options)
        result = m.call(resolve_template(renderer, layout, options), options) { result }
      end
      result
    end
    
    def determine_layout(renderer, template, options)
      return if options[:layout] == false
      layout_from_options = options[:layout] || :layout
      resolve_template(renderer, layout_from_options, options, false)
    end

    private
        
      def resolve_template(renderer, template, options, scream = true)
        case template
        when String
          template
        when Proc
          template.call
        when Symbol
          if proc = templates[template]
            resolve_template(renderer, proc, options, scream)
          else
            read_template_file(renderer, template, options, scream)
          end
        else
          nil
        end
      end
      
      def read_template_file(renderer, template, options, scream = true)
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
      end
      
      def templates
        Sinatra.application.templates
      end
    
  end

  module Erb
    
    def erb(content, options={})
      require 'erb'
      render(:erb, content, options)
    end
    
    private 
    
      def render_erb(content, options = {})
        ::ERB.new(content).result(binding)
      end
      
  end

  module Haml
    
    def haml(content, options={})
      require 'haml'
      render(:haml, content, options)
    end
    
    private
    
      def render_haml(content, options = {}, &b)
        ::Haml::Engine.new(content).render(options[:scope] || self, options[:locals] || {}, &b)
      end
        
  end

  # Generate valid CSS using Sass (part of Haml)
  #
  # Sass templates can be in external files with <tt>.sass</tt> extension or can use Sinatra's
  # in_file_templates.  In either case, the file can be rendered by passing the name of
  # the template to the +sass+ method as a symbol.
  #
  # Unlike Haml, Sass does not support a layout file, so the +sass+ method will ignore both
  # the default <tt>layout.sass</tt> file and any parameters passed in as <tt>:layout</tt> in
  # the options hash.
  #
  # === Sass Template Files
  #
  # Sass templates can be stored in separate files with a <tt>.sass</tt>
  # extension under the view path.
  #
  # Example:
  #   get '/stylesheet.css' do
  #     header 'Content-Type' => 'text/css; charset=utf-8'
  #     sass :stylesheet
  #   end
  #
  # The "views/stylesheet.sass" file might contain the following:
  #  
  #  body
  #    #admin
  #      :background-color #CCC
  #    #main
  #      :background-color #000
  #  #form
  #    :border-color #AAA
  #    :border-width 10px
  #
  # And yields the following output:
  #
  #   body #admin {
  #     background-color: #CCC; }
  #   body #main {
  #     background-color: #000; }
  #   
  #   #form {
  #     border-color: #AAA;
  #     border-width: 10px; }
  #   
  #
  # NOTE: Haml must be installed or a LoadError will be raised the first time an
  # attempt is made to render a Sass template.
  #
  # See http://haml.hamptoncatlin.com/docs/rdoc/classes/Sass.html for comprehensive documentation on Sass.

  
  module Sass
    
    def sass(content, options = {})
      require 'sass'
      
      # Sass doesn't support a layout, so we override any possible layout here
      options[:layout] = false
      
      render(:sass, content, options)
    end
    
    private
      
      def render_sass(content, options = {})
        ::Sass::Engine.new(content).render
      end
  end

  # Generating conservative XML content using Builder templates.
  #
  # Builder templates can be inline by passing a block to the builder method, or in
  # external files with +.builder+ extension by passing the name of the template
  # to the +builder+ method as a Symbol.
  #
  # === Inline Rendering
  #
  # If the builder method is given a block, the block is called directly with an 
  # +XmlMarkup+ instance and the result is returned as String:
  #   get '/who.xml' do
  #     builder do |xml|
  #       xml.instruct!
  #       xml.person do
  #         xml.name "Francis Albert Sinatra", 
  #           :aka => "Frank Sinatra"
  #         xml.email 'frank@capitolrecords.com'
  #       end
  #     end
  #   end
  #
  # Yields the following XML:
  #   <?xml version='1.0' encoding='UTF-8'?>
  #   <person>
  #     <name aka='Frank Sinatra'>Francis Albert Sinatra</name>
  #     <email>Frank Sinatra</email>
  #   </person>
  #
  # === Builder Template Files
  #
  # Builder templates can be stored in separate files with a +.builder+ 
  # extension under the view path. An +XmlMarkup+ object named +xml+ is automatically
  # made available to template.
  #
  # Example:
  #   get '/bio.xml' do
  #     builder :bio
  #   end
  #
  # The "views/bio.builder" file might contain the following:
  #   xml.instruct! :xml, :version => '1.1'
  #   xml.person do
  #     xml.name "Francis Albert Sinatra"
  #     xml.aka "Frank Sinatra"
  #     xml.aka "Ol' Blue Eyes"
  #     xml.aka "The Chairman of the Board"
  #     xml.born 'date' => '1915-12-12' do
  #       xml.text! "Hoboken, New Jersey, U.S.A."
  #     end
  #     xml.died 'age' => 82
  #   end
  #
  # And yields the following output:
  #   <?xml version='1.1' encoding='UTF-8'?>
  #   <person>
  #     <name>Francis Albert Sinatra</name>
  #     <aka>Frank Sinatra</aka>
  #     <aka>Ol&apos; Blue Eyes</aka>
  #     <aka>The Chairman of the Board</aka>
  #     <born date='1915-12-12'>Hoboken, New Jersey, U.S.A.</born>
  #     <died age='82' />
  #   </person>
  #
  # NOTE: Builder must be installed or a LoadError will be raised the first time an
  # attempt is made to render a builder template.
  #
  # See http://builder.rubyforge.org/ for comprehensive documentation on Builder.
  module Builder

    def builder(content=nil, options={}, &block)
      options, content = content, nil if content.is_a?(Hash)
      content = Proc.new { block } if content.nil?
      render(:builder, content, options)
    end

    private

      def render_builder(content, options = {}, &b)
        require 'builder'
        xml = ::Builder::XmlMarkup.new(:indent => 2)
        case content
        when String
          eval(content, binding, '<BUILDER>', 1)
        when Proc
          content.call(xml)
        end
        xml.target!
      end

  end

  class EventContext
    
    include ResponseHelpers
    include Streaming
    include RenderingHelpers
    include Erb
    include Haml
    include Builder
    include Sass
    
    attr_accessor :request, :response
    
    dslify_writer :status, :body
    
    def initialize(request, response, route_params)
      @request = request
      @response = response
      @route_params = route_params
      @response.body = nil
    end
    
    def params
      @params ||= begin 
        h = Hash.new {|h,k| h[k.to_s] if Symbol === k}
        h.merge(@route_params.merge(@request.params))
      end
    end

    def data
      @data ||= params.keys.first
    end
    
    def stop(*args)
      throw :halt, args
    end
    
    def complete(returned)
      @response.body || returned
    end
    
    def session
      @request.env['rack.session'] || {}
    end
    
    private

      def method_missing(name, *args, &b)
        @response.send(name, *args, &b)
      end
    
  end
  
  class Application
    
    attr_reader :events, :errors, :templates, :filters
    attr_reader :clearables, :reloading
    
    attr_writer :options
    
    def self.default_options
      @@default_options ||= {
        :run => true,
        :port => 4567,
        :env => :development,
        :root => Dir.pwd,
        :views => Dir.pwd + '/views',
        :public => Dir.pwd + '/public',
        :sessions => false,
        :logging => true,
      }
    end
    
    def default_options
      self.class.default_options
    end

    
    ##
    # Load all options given on the command line
    # NOTE:  Ignores --name so unit/spec tests can run individually
    def load_options!
      require 'optparse'
      OptionParser.new do |op|
        op.on('-p port') { |port| default_options[:port] = port }
        op.on('-e env') { |env| default_options[:env] = env }
        op.on('-x') { |env| default_options[:mutex] = true }
      end.parse!(ARGV.dup.select { |o| o !~ /--name/ })
    end

    # Called immediately after the application is initialized or reloaded to
    # register default events. Events added here have dibs on requests since
    # they appear first in the list.
    def load_default_events!
      events[:get] << Static.new
    end

    def initialize
      @clearables = [
        @events = Hash.new { |hash, key| hash[key] = [] },
        @errors = Hash.new,
        @filters = Hash.new { |hash, key| hash[key] = [] },
        @templates = Hash.new
      ]
      load_options!
      load_default_events!
    end

    def define_event(method, path, options = {}, &b)
      events[method] << event = Event.new(path, options, &b)
      event
    end
    
    def define_template(name=:layout, &b)
      templates[name] = b
    end
    
    def define_error(code, options = {}, &b)
      errors[code] = Error.new(code, &b)
    end
    
    def define_filter(type, &b)
      filters[:before] << b
    end

    # Visits and invokes each handler registered for the +request_method+ in
    # definition order until a Result response is produced. If no handler
    # responds with a Result, the NotFound error handler is invoked.
    #
    # When the request_method is "HEAD" and no valid Result is produced by
    # the set of handlers registered for HEAD requests, an attempt is made to
    # invoke the GET handlers to generate the response before resorting to the
    # default error handler.
    def lookup(request)
      method = request.request_method.downcase.to_sym
      events[method].eject(&[:invoke, request]) ||
        (events[:get].eject(&[:invoke, request]) if method == :head) ||
        errors[NotFound].invoke(request)
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
      load_default_events!
      Kernel.load $0
      @reloading = false
      Environment.setup!
    end
    
    def mutex
      @@mutex ||= Mutex.new
    end
    
    def run_safely
      if options.mutex
        mutex.synchronize { yield }
      else
        yield
      end
    end
    
    def call(env)
      reload! if development?
      request = Rack::Request.new(env)
      result = lookup(request)
      context = EventContext.new(
        request, 
        Rack::Response.new,
        result.params
      )
      context.status(result.status)
      begin
        returned = run_safely do
          catch(:halt) do
            filters[:before].each { |f| context.instance_eval(&f) }
            [:complete, context.instance_eval(&result.block)]
          end
        end
        body = returned.to_result(context)
      rescue => e
        request.env['sinatra.error'] = e
        context.status(500)
        result = (errors[e.class] || errors[ServerError]).invoke(request)
        returned = run_safely do
          catch(:halt) do
            [:complete, context.instance_eval(&result.block)]
          end
        end
        body = returned.to_result(context)
      end
      body = '' unless body.respond_to?(:each)
      body = '' if request.request_method.upcase == 'HEAD'
      context.body = body.kind_of?(String) ? [*body] : body
      context.finish
    end
    
  end
  
  
  module Environment
    extend self
    
    def setup!
      configure do
        error do
          raise request.env['sinatra.error'] if Sinatra.options.raise_errors
          '<h1>Internal Server Error</h1>'
        end
        not_found { '<h1>Not Found</h1>'}
      end
      
      configures :development do

        get '/sinatra_custom_images/:image.png' do
          File.read(File.dirname(__FILE__) + "/../images/#{params[:image]}.png")
        end

        not_found do
          %Q(
          <style>
          body {
            text-align: center; 
            color: #888;
            font-family: Arial; 
            font-size: 22px; 
            margin: 20px;
          }
          #content {
            margin: 0 auto;
            width: 500px;
            text-align: left;
          }
          </style>
          <html>
            <body>
              <h2>Sinatra doesn't know this diddy.</h2>
              <img src='/sinatra_custom_images/404.png'></img>
              <div id="content">
                Try this:
<pre>#{request.request_method.downcase} "#{request.path_info}" do
  .. do something ..
end<pre>
              </div>
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
            		<div class="info">
                  Params: <pre>#{params.inspect}
            		</div>
          			<div id="stacktrace">
          				<h1>#{Rack::Utils.escape_html(@error.class.name + ' - ' + @error.message)}</h1>
          				<pre><code>#{Rack::Utils.escape_html(@error.backtrace.join("\n"))}</code></pre>
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
  Sinatra.application.define_template(name, &b)
end

def template(name, &b)
  Sinatra.application.define_template(name, &b)
end

def use_in_file_templates!
  require 'stringio'
  templates = IO.read(caller.first.split(':').first).split('__FILE__').last
  data = StringIO.new(templates)
  current_template = nil
  data.each do |line|
    if line =~ /^##\s?(.*)/
      current_template = $1.to_sym
      Sinatra.application.templates[current_template] = ''
    elsif current_template
      Sinatra.application.templates[current_template] << line
    end
  end
end

def configures(*envs, &b)
  yield if  !Sinatra.application.reloading && 
            (envs.include?(Sinatra.application.options.env) ||
            envs.empty?)
end
alias :configure :configures

def set_options(opts)
  Sinatra::Application.default_options.merge!(opts)
  Sinatra.application.options = nil
end

def set_option(key, value)
  set_options(key => value)
end

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
    args.shift.to_result(cx, *args)
  end
end

class String
  def to_result(cx, *args)
    args.shift.to_result(cx, *args)
    self
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
    args.shift.to_result(cx, *args)
  end
end

class NilClass
  def to_result(cx, *args)
    ''
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
