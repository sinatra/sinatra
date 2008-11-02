require 'time'
require 'ostruct'
require 'uri'
require 'rack'

if ENV['SWIFT']
 require 'swiftcore/swiftiplied_mongrel'
 puts "Using Swiftiplied Mongrel"
elsif ENV['EVENT']
  require 'swiftcore/evented_mongrel'
  puts "Using Evented Mongrel"
end

module Rack #:nodoc:

  class Request #:nodoc:

    # Set of request method names allowed via the _method parameter hack. By
    # default, all request methods defined in RFC2616 are included, with the
    # exception of TRACE and CONNECT.
    POST_TUNNEL_METHODS_ALLOWED = %w( PUT DELETE OPTIONS HEAD )

    # Return the HTTP request method with support for method tunneling using
    # the POST _method parameter hack. If the real request method is POST and
    # a _method param is given and the value is one defined in
    # +POST_TUNNEL_METHODS_ALLOWED+, return the value of the _method param
    # instead.
    def request_method
      if post_tunnel_method_hack?
        params['_method'].upcase
      else
        @env['REQUEST_METHOD']
      end
    end

    def user_agent
      @env['HTTP_USER_AGENT']
    end

  private

    # Return truthfully if the request is a valid verb-over-post hack.
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

  VERSION = '0.3.2'

  class NotFound < RuntimeError
    def self.code ; 404 ; end
  end
  class ServerError < RuntimeError
    def self.code ; 500 ; end
  end

  Result = Struct.new(:block, :params, :status) unless defined?(Result)

  def options
    application.options
  end

  def application
    @app ||= Application.new
  end

  def application=(app)
    @app = app
  end

  def port
    application.options.port
  end

  def host
    application.options.host
  end

  def env
    application.options.env
  end

  # Deprecated: use application instead of build_application.
  alias :build_application :application

  def server
    options.server ||= defined?(Rack::Handler::Thin) ? "thin" : "mongrel"

    # Convert the server into the actual handler name
    handler = options.server.capitalize

    # If the convenience conversion didn't get us anything,
    # fall back to what the user actually set.
    handler = options.server unless Rack::Handler.const_defined?(handler)

    @server ||= eval("Rack::Handler::#{handler}")
  end

  def run
    begin
      puts "== Sinatra/#{Sinatra::VERSION} has taken the stage on port #{port} for #{env} with backup by #{server.name}"
      server.run(application, {:Port => port, :Host => host}) do |server|
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
    include Rack::Utils

    URI_CHAR = '[^/?:,&#\.]'.freeze unless defined?(URI_CHAR)
    PARAM = /(:(#{URI_CHAR}+)|\*)/.freeze unless defined?(PARAM)
    SPLAT = /(.*?)/
    attr_reader :path, :block, :param_keys, :pattern, :options

    def initialize(path, options = {}, &b)
      @path = URI.encode(path)
      @block = b
      @param_keys = []
      @options = options
      splats = 0
      regex = @path.to_s.gsub(PARAM) do |match|
        if match == "*"
          @param_keys << "_splat_#{splats}"
          splats += 1
          SPLAT.to_s
        else
          @param_keys << $2
          "(#{URI_CHAR}+)"
        end
      end

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
      path_params = param_keys.zip($~.captures.map{|s| unescape(s) if s}).to_hash
      params.merge!(path_params)
      splats = params.select { |k, v| k =~ /^_splat_\d+$/ }.sort.map(&:last)
      unless splats.empty?
        params.delete_if { |k, v| k =~ /^_splat_\d+$/ }
        params["splat"] = splats
      end
      Result.new(block, params, 200)
    end

  end

  class Error

    attr_reader :type, :block, :options

    def initialize(type, options={}, &block)
      @type = type
      @block = block
      @options = options
    end

    def invoke(request)
      Result.new(block, options, code)
    end

    def code
      if type.respond_to?(:code)
        type.code
      else
        500
      end
    end

  end

  class Static
    include Rack::Utils

    def initialize(app)
      @app = app
    end

    def invoke(request)
      path = @app.options.public + unescape(request.path_info)
      return unless File.file?(path)
      block = Proc.new { send_file path, :disposition => nil }
      Result.new(block, {}, 200)
    end
  end

  # Methods for sending files and streams to the browser instead of rendering.
  module Streaming
    DEFAULT_SEND_FILE_OPTIONS = {
      :type         => 'application/octet-stream'.freeze,
      :disposition  => 'attachment'.freeze,
      :stream       => true,
      :buffer_size  => 8192
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
        size = options[:buffer_size]
        File.open(path, 'rb') do |file|
          while buf = file.read(size)
            yield buf
          end
        end
      end
    end

  protected
    # Sends the file by streaming it 8192 bytes at a time. This way the
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
    # * <tt>:disposition</tt> - specifies whether the file will be shown
    #   inline or downloaded. Valid values are 'inline' and 'attachment'
    #   (default). When set to nil, the Content-Disposition and
    #   Content-Transfer-Encoding headers are omitted entirely.
    # * <tt>:stream</tt> - whether to send the file to the user agent as it
    #   is read (true) or to read the entire file before sending (false).
    #   Defaults to true.
    # * <tt>:buffer_size</tt> - specifies size (in bytes) of the buffer used
    #   to stream the file. Defaults to 8192.
    # * <tt>:status</tt> - specifies the status code to send with the
    #   response. Defaults to '200 OK'.
    # * <tt>:last_modified</tt> - an optional RFC 2616 formatted date value
    #   (See Time#httpdate) indicating the last modified time of the file.
    #   If the request includes an If-Modified-Since header that matches this
    #   value exactly, a 304 Not Modified response is sent instead of the file.
    #   Defaults to the file's last modified time.
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
    #   send_file '/path/to.jpeg',
    #     :type => 'image/jpeg',
    #     :disposition => 'inline'
    #
    # Show a 404 page in the browser:
    #   send_file '/path/to/404.html,
    #     :type => 'text/html; charset=utf-8',
    #     :status => 404
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
      options[:stream] = true unless options.key?(:stream)
      options[:buffer_size] ||= DEFAULT_SEND_FILE_OPTIONS[:buffer_size]
      send_file_headers! options

      if options[:stream]
        throw :halt, [options[:status] || 200, FileStreamer.new(path, options)]
      else
        File.open(path, 'rb') { |file| throw :halt, [options[:status] || 200, [file.read]] }
      end
    end

    # Send binary data to the user as a file download. May set content type,
    # apparent file name, and specify whether to show data inline or download
    # as an attachment.
    #
    # Options:
    # * <tt>:filename</tt> - Suggests a filename for the browser to use.
    # * <tt>:type</tt> - specifies an HTTP content type.
    #   Defaults to 'application/octet-stream'.
    # * <tt>:disposition</tt> - specifies whether the file will be shown inline
    #   or downloaded. Valid values are 'inline' and 'attachment' (default).
    # * <tt>:status</tt> - specifies the status code to send with the response.
    #   Defaults to '200 OK'.
    # * <tt>:last_modified</tt> - an optional RFC 2616 formatted date value (See
    #   Time#httpdate) indicating the last modified time of the response entity.
    #   If the request includes an If-Modified-Since header that matches this
    #   value exactly, a 304 Not Modified response is sent instead of the data.
    #
    # Generic data download:
    #   send_data buffer
    #
    # Download a dynamically-generated tarball:
    #   send_data generate_tgz('dir'), :filename => 'dir.tgz'
    #
    # Display an image Active Record in the browser:
    #   send_data image.data,
    #     :type => image.content_type,
    #     :disposition => 'inline'
    #
    # See +send_file+ for more information on HTTP Content-* headers and caching.
    def send_data(data, options = {}) #:doc:
      send_file_headers! options.merge(:length => data.size)
      throw :halt, [options[:status] || 200, [data]]
    end

  private

    def send_file_headers!(options)
      options = DEFAULT_SEND_FILE_OPTIONS.merge(options)
      [:length, :type, :disposition].each do |arg|
        raise ArgumentError, ":#{arg} option required" unless options.key?(arg)
      end

      # Send a "304 Not Modified" if the last_modified option is provided and
      # matches the If-Modified-Since request header value.
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


  # Helper methods for building various aspects of the HTTP response.
  module ResponseHelpers

    # Immediately halt response execution by redirecting to the resource
    # specified. The +path+ argument may be an absolute URL or a path
    # relative to the site root. Additional arguments are passed to the
    # halt.
    #
    # With no integer status code, a '302 Temporary Redirect' response is
    # sent. To send a permanent redirect, pass an explicit status code of
    # 301:
    #
    #   redirect '/somewhere/else', 301
    #
    # NOTE: No attempt is made to rewrite the path based on application
    # context. The 'Location' response header is set verbatim to the value
    # provided.
    def redirect(path, *args)
      status(302)
      header 'Location' => path
      throw :halt, *args
    end

    # Access or modify response headers. With no argument, return the
    # underlying headers Hash. With a Hash argument, add or overwrite
    # existing response headers with the values provided:
    #
    #    headers 'Content-Type' => "text/html;charset=utf-8",
    #      'Last-Modified' => Time.now.httpdate,
    #      'X-UA-Compatible' => 'IE=edge'
    #
    # This method also available in singular form (#header).
    def headers(header = nil)
      @response.headers.merge!(header) if header
      @response.headers
    end
    alias :header :headers

    # Set the content type of the response body (HTTP 'Content-Type' header).
    #
    # The +type+ argument may be an internet media type (e.g., 'text/html',
    # 'application/xml+atom', 'image/png') or a Symbol key into the
    # Rack::File::MIME_TYPES table.
    #
    # Media type parameters, such as "charset", may also be specified using the
    # optional hash argument:
    #
    #   get '/foo.html' do
    #     content_type 'text/html', :charset => 'utf-8'
    #     "<h1>Hello World</h1>"
    #   end
    #
    def content_type(type, params={})
      type = Rack::File::MIME_TYPES[type.to_s] if type.kind_of?(Symbol)
      fail "Invalid or undefined media_type: #{type}" if type.nil?
      if params.any?
        params = params.collect { |kv| "%s=%s" % kv }.join(', ')
        type = [ type, params ].join(";")
      end
      response.header['Content-Type'] = type
    end

    # Set the last modified time of the resource (HTTP 'Last-Modified' header)
    # and halt if conditional GET matches. The +time+ argument is a Time,
    # DateTime, or other object that responds to +to_time+.
    #
    # When the current request includes an 'If-Modified-Since' header that
    # matches the time specified, execution is immediately halted with a
    # '304 Not Modified' response.
    #
    # Calling this method before perfoming heavy processing (e.g., lengthy
    # database queries, template rendering, complex logic) can dramatically
    # increase overall throughput with caching clients.
    def last_modified(time)
      time = time.to_time if time.respond_to?(:to_time)
      time = time.httpdate if time.respond_to?(:httpdate)
      response.header['Last-Modified'] = time
      throw :halt, 304 if time == request.env['HTTP_IF_MODIFIED_SINCE']
      time
    end

    # Set the response entity tag (HTTP 'ETag' header) and halt if conditional
    # GET matches. The +value+ argument is an identifier that uniquely
    # identifies the current version of the resource. The +strength+ argument
    # indicates whether the etag should be used as a :strong (default) or :weak
    # cache validator.
    #
    # When the current request includes an 'If-None-Match' header with a
    # matching etag, execution is immediately halted. If the request method is
    # GET or HEAD, a '304 Not Modified' response is sent. For all other request
    # methods, a '412 Precondition Failed' response is sent.
    #
    # Calling this method before perfoming heavy processing (e.g., lengthy
    # database queries, template rendering, complex logic) can dramatically
    # increase overall throughput with caching clients.
    #
    # ==== See Also
    # {RFC2616: ETag}[http://w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.19],
    # ResponseHelpers#last_modified
    def entity_tag(value, strength=:strong)
      value =
        case strength
        when :strong then '"%s"' % value
        when :weak   then 'W/"%s"' % value
        else         raise TypeError, "strength must be one of :strong or :weak"
        end
      response.header['ETag'] = value

      # Check for If-None-Match request header and halt if match is found.
      etags = (request.env['HTTP_IF_NONE_MATCH'] || '').split(/\s*,\s*/)
      if etags.include?(value) || etags.include?('*')
        # GET/HEAD requests: send Not Modified response
        throw :halt, 304 if request.get? || request.head?
        # Other requests: send Precondition Failed response
        throw :halt, 412
      end
    end

    alias :etag :entity_tag

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
      locals_opt = options.delete(:locals) || {}

      locals_code = ""
      locals_hash = {}
      locals_opt.each do |key, value|
        locals_code << "#{key} = locals_hash[:#{key}]\n"
        locals_hash[:"#{key}"] = value
      end

      body = ::ERB.new(content).src
      eval("#{locals_code}#{body}", binding)
    end

  end

  module Haml

    def haml(content, options={})
      require 'haml'
      render(:haml, content, options)
    end

  private

    def render_haml(content, options = {}, &b)
      haml_options = (options[:options] || {}).
        merge(Sinatra.options.haml || {})
      ::Haml::Engine.new(content, haml_options).
        render(options[:scope] || self, options[:locals] || {}, &b)
    end

  end

  # Generate valid CSS using Sass (part of Haml)
  #
  # Sass templates can be in external files with <tt>.sass</tt> extension
  # or can use Sinatra's in_file_templates.  In either case, the file can
  # be rendered by passing the name of the template to the +sass+ method
  # as a symbol.
  #
  # Unlike Haml, Sass does not support a layout file, so the +sass+ method
  # will ignore both the default <tt>layout.sass</tt> file and any parameters
  # passed in as <tt>:layout</tt> in the options hash.
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
  # Builder templates can be inline by passing a block to the builder method,
  # or in external files with +.builder+ extension by passing the name of the
  # template to the +builder+ method as a Symbol.
  #
  # === Inline Rendering
  #
  # If the builder method is given a block, the block is called directly with
  # an +XmlMarkup+ instance and the result is returned as String:
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
  # extension under the view path. An +XmlMarkup+ object named +xml+ is
  # automatically made available to template.
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
  # NOTE: Builder must be installed or a LoadError will be raised the first
  # time an attempt is made to render a builder template.
  #
  # See http://builder.rubyforge.org/ for comprehensive documentation on
  # Builder.
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
    include Rack::Utils
    include ResponseHelpers
    include Streaming
    include RenderingHelpers
    include Erb
    include Haml
    include Builder
    include Sass

    attr_accessor :request, :response

    attr_accessor :route_params

    def initialize(request, response, route_params)
      @params = nil
      @data = nil
      @request = request
      @response = response
      @route_params = route_params
      @response.body = nil
    end

    def status(value=nil)
      response.status = value if value
      response.status
    end

    def body(value=nil)
      response.body = value if value
      response.body
    end

    def params
      @params ||=
        begin
          hash = Hash.new {|h,k| h[k.to_s] if Symbol === k}
          hash.merge! @request.params
          hash.merge! @route_params
          hash
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
      request.env['rack.session'] ||= {}
    end

    def reset!
      @params = nil
      @data = nil
    end

  private

    def method_missing(name, *args, &b)
      if @response.respond_to?(name)
        @response.send(name, *args, &b)
      else
        super
      end
    end

  end


  # The Application class represents the top-level working area of a
  # Sinatra app. It provides the DSL for defining various aspects of the
  # application and implements a Rack compatible interface for dispatching
  # requests.
  #
  # Many of the instance methods defined in this class (#get, #post,
  # #put, #delete, #layout, #before, #error, #not_found, etc.) are
  # available at top-level scope. When invoked from top-level, the
  # messages are forwarded to the "default application" (accessible
  # at Sinatra::application).
  class Application

    # Hash of event handlers with request method keys and
    # arrays of potential handlers as values.
    attr_reader :events

    # Hash of error handlers with error status codes as keys and
    # handlers as values.
    attr_reader :errors

    # Hash of template name mappings.
    attr_reader :templates

    # Hash of filters with event name keys (:before) and arrays of
    # handlers as values.
    attr_reader :filters

    # Array of objects to clear during reload. The objects in this array
    # must respond to :clear.
    attr_reader :clearables

    # Object including open attribute methods for modifying Application
    # configuration.
    attr_reader :options

    # List of methods available from top-level scope. When invoked from
    # top-level the method is forwarded to the default application
    # (Sinatra::application).
    FORWARD_METHODS = %w[
      get put post delete head template layout before error not_found
      configures configure set set_options set_option enable disable use
      development? test? production?
    ]

    # Create a new Application with a default configuration taken
    # from the default_options Hash.
    #
    # NOTE: A default Application is automatically created the first
    # time any of Sinatra's DSL related methods is invoked so there
    # is typically no need to create an instance explicitly. See
    # Sinatra::application for more information.
    def initialize
      @reloading = false
      @clearables = [
        @events = Hash.new { |hash, key| hash[key] = [] },
        @errors = Hash.new,
        @filters = Hash.new { |hash, key| hash[key] = [] },
        @templates = Hash.new,
        @middleware = []
      ]
      @options = OpenStruct.new(self.class.default_options)
      load_default_configuration!
    end

    # Hash of default application configuration options. When a new
    # Application is created, the #options object takes its initial values
    # from here.
    #
    # Changes to the default_options Hash effect only Application objects
    # created after the changes are made. For this reason, modifications to
    # the default_options Hash typically occur at the very beginning of a
    # file, before any DSL related functions are invoked.
    def self.default_options
      return @default_options unless @default_options.nil?
      root = File.expand_path(File.dirname($0))
      @default_options = {
        :run => true,
        :port => 4567,
        :host => '0.0.0.0',
        :env => :development,
        :root => root,
        :views => root + '/views',
        :public => root + '/public',
        :sessions => false,
        :logging => true,
        :app_file => $0,
        :raise_errors => false
      }
      load_default_options_from_command_line!
      @default_options
    end

    # Search ARGV for command line arguments and update the
    # Sinatra::default_options Hash accordingly. This method is
    # invoked the first time the default_options Hash is accessed.
    # NOTE:  Ignores --name so unit/spec tests can run individually
    def self.load_default_options_from_command_line! #:nodoc:
      # fixes issue with: gem install --test sinatra
      return if ARGV.empty? || File.basename($0) =~ /gem/
      require 'optparse'
      OptionParser.new do |op|
        op.on('-p port') { |port| default_options[:port] = port }
        op.on('-e env') { |env| default_options[:env] = env.to_sym }
        op.on('-x') { default_options[:mutex] = true }
        op.on('-s server') { |server| default_options[:server] = server }
      end.parse!(ARGV.dup.select { |o| o !~ /--name/ })
    end

    # Determine whether the application is in the process of being
    # reloaded.
    def reloading?
      @reloading == true
    end

    # Yield to the block for configuration if the current environment
    # matches any included in the +envs+ list. Always yield to the block
    # when no environment is specified.
    #
    # NOTE: configuration blocks are not executed during reloads.
    def configures(*envs, &b)
      return if reloading?
      yield self if envs.empty? || envs.include?(options.env)
    end

    alias :configure :configures

    # When both +option+ and +value+ arguments are provided, set the option
    # specified. With a single Hash argument, set all options specified in
    # Hash. Options are available via the Application#options object.
    #
    # Setting individual options:
    #   set :port, 80
    #   set :env, :production
    #   set :views, '/path/to/views'
    #
    # Setting multiple options:
    #   set :port  => 80,
    #       :env   => :production,
    #       :views => '/path/to/views'
    #
    def set(option, value=self)
      if value == self && option.kind_of?(Hash)
        option.each { |key,val| set(key, val) }
      else
        options.send("#{option}=", value)
      end
    end

    alias :set_option :set
    alias :set_options :set

    # Enable the options specified by setting their values to true. For
    # example, to enable sessions and logging:
    #   enable :sessions, :logging
    def enable(*opts)
      opts.each { |key| set(key, true) }
    end

    # Disable the options specified by setting their values to false. For
    # example, to disable logging and automatic run:
    #   disable :logging, :run
    def disable(*opts)
      opts.each { |key| set(key, false) }
    end

    # Define an event handler for the given request method and path
    # spec. The block is executed when a request matches the method
    # and spec.
    #
    # NOTE: The #get, #post, #put, and #delete helper methods should
    # be used to define events when possible.
    def event(method, path, options = {}, &b)
      events[method].push(Event.new(path, options, &b)).last
    end

    # Define an event handler for GET requests.
    def get(path, options={}, &b)
      event(:get, path, options, &b)
    end

    # Define an event handler for POST requests.
    def post(path, options={}, &b)
      event(:post, path, options, &b)
    end

    # Define an event handler for HEAD requests.
    def head(path, options={}, &b)
      event(:head, path, options, &b)
    end

    # Define an event handler for PUT requests.
    #
    # NOTE: PUT events are triggered when the HTTP request method is
    # PUT and also when the request method is POST and the body includes a
    # "_method" parameter set to "PUT".
    def put(path, options={}, &b)
      event(:put, path, options, &b)
    end

    # Define an event handler for DELETE requests.
    #
    # NOTE: DELETE events are triggered when the HTTP request method is
    # DELETE and also when the request method is POST and the body includes a
    # "_method" parameter set to "DELETE".
    def delete(path, options={}, &b)
      event(:delete, path, options, &b)
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

    # Define a named template. The template may be referenced from
    # event handlers by passing the name as a Symbol to rendering
    # methods. The block is executed each time the template is rendered
    # and the resulting object is passed to the template handler.
    #
    # The following example defines a HAML template named hello and
    # invokes it from an event handler:
    #
    #   template :hello do
    #     "h1 Hello World!"
    #   end
    #
    #   get '/' do
    #     haml :hello
    #   end
    #
    def template(name, &b)
      templates[name] = b
    end

    # Define a layout template.
    def layout(name=:layout, &b)
      template(name, &b)
    end

    # Define a custom error handler for the exception class +type+. The block
    # is invoked when the specified exception type is raised from an error
    # handler and can manipulate the response as needed:
    #
    #   error MyCustomError do
    #     status 500
    #     'So what happened was...' + request.env['sinatra.error'].message
    #   end
    #
    # The Sinatra::ServerError handler is used by default when an exception
    # occurs and no matching error handler is found.
    def error(type=ServerError, options = {}, &b)
      errors[type] = Error.new(type, options, &b)
    end

    # Define a custom error handler for '404 Not Found' responses. This is a
    # shorthand for:
    #   error NotFound do
    #     ..
    #   end
    def not_found(options={}, &b)
      error NotFound, options, &b
    end

    # Define a request filter. When <tt>type</tt> is <tt>:before</tt>, execute the
    # block in the context of each request before matching event handlers.
    def filter(type, &b)
      filters[type] << b
    end

    # Invoke the block in the context of each request before invoking
    # matching event handlers.
    def before(&b)
      filter :before, &b
    end

    # True when environment is :development.
    def development? ; options.env == :development ; end

    # True when environment is :test.
    def test? ; options.env == :test ; end

    # True when environment is :production.
    def production? ; options.env == :production ; end

    # Clear all events, templates, filters, and error handlers
    # and then reload the application source file. This occurs
    # automatically before each request is processed in development.
    def reload!
      clearables.each(&:clear)
      load_default_configuration!
      load_development_configuration! if development?
      @pipeline = nil
      @reloading = true
      Kernel.load options.app_file
      @reloading = false
    end

    # Determine whether the application is in the process of being
    # reloaded.
    def reloading?
      @reloading == true
    end

    # Mutex instance used for thread synchronization.
    def mutex
      @@mutex ||= Mutex.new
    end

    # Yield to the block with thread synchronization
    def run_safely
      if development? || options.mutex
        mutex.synchronize { yield }
      else
        yield
      end
    end

    # Add a piece of Rack middleware to the pipeline leading to the
    # application.
    def use(klass, *args, &block)
      fail "#{klass} must respond to 'new'" unless klass.respond_to?(:new)
      @pipeline = nil
      @middleware.push([ klass, args, block ]).last
    end

  private

    # Rack middleware derived from current state of application options.
    # These components are plumbed in at the very beginning of the
    # pipeline.
    def optional_middleware
      [
        ([ Rack::CommonLogger,    [], nil ] if options.logging),
        ([ Rack::Session::Cookie, [], nil ] if options.sessions)
      ].compact
    end

    # Rack middleware explicitly added to the application with #use. These
    # components are plumbed into the pipeline downstream from
    # #optional_middle.
    def explicit_middleware
      @middleware
    end

    # All Rack middleware used to construct the pipeline.
    def middleware
      optional_middleware + explicit_middleware
    end

  public

    # An assembled pipeline of Rack middleware that leads eventually to
    # the Application#invoke method. The pipeline is built upon first
    # access. Defining new middleware with Application#use or manipulating
    # application options may cause the pipeline to be rebuilt.
    def pipeline
      @pipeline ||=
        middleware.inject(method(:dispatch)) do |app,(klass,args,block)|
          klass.new(app, *args, &block)
        end
    end

    # Rack compatible request invocation interface.
    def call(env)
      run_safely do
        reload! if development? && (options.reload != false)
        pipeline.call(env)
      end
    end

    # Request invocation handler - called at the end of the Rack pipeline
    # for each request.
    #
    # 1. Create Rack::Request, Rack::Response helper objects.
    # 2. Lookup event handler based on request method and path.
    # 3. Create new EventContext to house event handler evaluation.
    # 4. Invoke each #before filter in context of EventContext object.
    # 5. Invoke event handler in context of EventContext object.
    # 6. Return response to Rack.
    #
    # See the Rack specification for detailed information on the
    # +env+ argument and return value.
    def dispatch(env)
      request = Rack::Request.new(env)
      context = EventContext.new(request, Rack::Response.new([], 200), {})
      begin
        returned =
          catch(:halt) do
            filters[:before].each { |f| context.instance_eval(&f) }
            result = lookup(context.request)
            context.route_params = result.params
            context.response.status = result.status
            context.reset!
            [:complete, context.instance_eval(&result.block)]
          end
        body = returned.to_result(context)
      rescue => e
        request.env['sinatra.error'] = e
        context.status(500)
        raise if options.raise_errors && e.class != NotFound
        result = (errors[e.class] || errors[ServerError]).invoke(request)
        returned =
          catch(:halt) do
            [:complete, context.instance_eval(&result.block)]
          end
        body = returned.to_result(context)
      end
      body = '' unless body.respond_to?(:each)
      body = '' if request.env["REQUEST_METHOD"].upcase == 'HEAD'
      context.body = body.kind_of?(String) ? [*body] : body
      context.finish
    end

  private

    # Called immediately after the application is initialized or reloaded to
    # register default events, templates, and error handlers.
    def load_default_configuration!
      events[:get] << Static.new(self)
      configure do
        error do
          '<h1>Internal Server Error</h1>'
        end
        not_found { '<h1>Not Found</h1>'}
      end
    end

    # Called before reloading to perform development specific configuration.
    def load_development_configuration!
      get '/sinatra_custom_images/:image.png' do
        content_type :png
        File.read(File.dirname(__FILE__) + "/../images/#{params[:image]}.png")
      end

      not_found do
        (<<-HTML).gsub(/^ {8}/, '')
        <!DOCTYPE html>
        <html>
          <head>
            <style type="text/css">
            body {text-align:center;color:#888;font-family:arial;font-size:22px;margin:20px;}
            #content {margin:0 auto;width:500px;text-align:left}
            </style>
          </head>
          <body>
            <h2>Sinatra doesn't know this diddy.</h2>
            <img src='/sinatra_custom_images/404.png'>
            <div id="content">
              Try this:
              <pre>#{request.request_method.downcase} "#{request.path_info}" do\n  .. do something ..\nend<pre>
            </div>
          </body>
        </html>
        HTML
      end

      error do
        @error = request.env['sinatra.error']
        (<<-HTML).gsub(/^ {8}/, '')
        <!DOCTYPE html>
        <html>
          <head>
            <style type="text/css" media="screen">
              body {font-family:verdana;color:#333}
              #content {width:700px;margin-left:20px}
              #content h1 {width:99%;color:#1D6B8D;font-weight:bold}
              #stacktrace {margin-top:-20px}
              #stacktrace pre {font-size:12px;border-left:2px solid #ddd;padding-left:10px}
              #stacktrace img {margin-top:10px}
            </style>
          </head>
          <body>
            <div id="content">
              <img src="/sinatra_custom_images/500.png">
              <div class="info">
                Params: <pre>#{params.inspect}</pre>
              </div>
              <div id="stacktrace">
                <h1>#{escape_html(@error.class.name + ' - ' + @error.message.to_s)}</h1>
                <pre><code>#{escape_html(@error.backtrace.join("\n"))}</code></pre>
              </div>
            </div>
          </body>
        </html>
        HTML
      end
    end

  end

end

# Delegate DSLish methods to the currently active Sinatra::Application
# instance.
Sinatra::Application::FORWARD_METHODS.each do |method|
  eval(<<-EOS, binding, '(__DSL__)', 1)
    def #{method}(*args, &b)
      Sinatra.application.#{method}(*args, &b)
    end
  EOS
end

def helpers(&b)
  Sinatra::EventContext.class_eval(&b)
end

def use_in_file_templates!
  require 'stringio'
  templates = IO.read(caller.first.split(':').first).split('__FILE__').last
  data = StringIO.new(templates)
  current_template = nil
  data.each do |line|
    if line =~ /^@@\s?(.*)/
      current_template = $1.to_sym
      Sinatra.application.templates[current_template] = ''
    elsif current_template
      Sinatra.application.templates[current_template] << line
    end
  end
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
  Sinatra.run if Sinatra.application.options.run
end

mime :xml, 'application/xml'
mime :js,  'application/javascript'
mime :png, 'image/png'
