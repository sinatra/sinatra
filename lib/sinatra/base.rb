require 'thread'
require 'time'
require 'uri'
require 'rack'
require 'rack/builder'
require 'sinatra/showexceptions'

# require tilt if available; fall back on bundled version.
begin
  require 'tilt'
  if Tilt::VERSION < '0.8'
    warn "WARN: sinatra requires tilt >= 0.8; you have #{Tilt::VERSION}. " +
         "loading bundled version..."
    Object.send :remove_const, :Tilt
    raise LoadError
  end
rescue LoadError
  require 'sinatra/tilt'
end

module Sinatra
  VERSION = '1.0'

  # The request object. See Rack::Request for more info:
  # http://rack.rubyforge.org/doc/classes/Rack/Request.html
  class Request < Rack::Request
    # Returns an array of acceptable media types for the response
    def accept
      @env['HTTP_ACCEPT'].to_s.split(',').map { |a| a.strip }
    end

    def secure?
      (@env['HTTP_X_FORWARDED_PROTO'] || @env['rack.url_scheme']) == 'https'
    end

    # Override Rack < 1.1's Request#params implementation (see lh #72 for
    # more info) and add a Request#user_agent method.
    # XXX remove when we require rack > 1.1
    if Rack.release < '1.1'
      def params
        self.GET.update(self.POST)
      rescue EOFError, Errno::ESPIPE
        self.GET
      end

      def user_agent
        @env['HTTP_USER_AGENT']
      end
    end
  end

  # The response object. See Rack::Response and Rack::ResponseHelpers for
  # more info:
  # http://rack.rubyforge.org/doc/classes/Rack/Response.html
  # http://rack.rubyforge.org/doc/classes/Rack/Response/Helpers.html
  class Response < Rack::Response
    def finish
      @body = block if block_given?
      if [204, 304].include?(status.to_i)
        header.delete "Content-Type"
        [status.to_i, header.to_hash, []]
      else
        body = @body || []
        body = [body] if body.respond_to? :to_str
        if body.respond_to?(:to_ary)
          header["Content-Length"] = body.to_ary.
            inject(0) { |len, part| len + Rack::Utils.bytesize(part) }.to_s
        end
        [status.to_i, header.to_hash, body]
      end
    end
  end

  class NotFound < NameError #:nodoc:
    def code ; 404 ; end
  end

  # Methods available to routes, before/after filters, and views.
  module Helpers
    # Set or retrieve the response status code.
    def status(value=nil)
      response.status = value if value
      response.status
    end

    # Set or retrieve the response body. When a block is given,
    # evaluation is deferred until the body is read with #each.
    def body(value=nil, &block)
      if block_given?
        def block.each ; yield call ; end
        response.body = block
      else
        response.body = value
      end
    end

    # Halt processing and redirect to the URI provided.
    def redirect(uri, *args)
      status 302
      response['Location'] = uri
      halt(*args)
    end

    # Halt processing and return the error status provided.
    def error(code, body=nil)
      code, body    = 500, code.to_str if code.respond_to? :to_str
      response.body = body unless body.nil?
      halt code
    end

    # Halt processing and return a 404 Not Found.
    def not_found(body=nil)
      error 404, body
    end

    # Set multiple response headers with Hash.
    def headers(hash=nil)
      response.headers.merge! hash if hash
      response.headers
    end

    # Access the underlying Rack session.
    def session
      env['rack.session'] ||= {}
    end

    # Look up a media type by file extension in Rack's mime registry.
    def mime_type(type)
      Base.mime_type(type)
    end

    # Set the Content-Type of the response body given a media type or file
    # extension.
    def content_type(type, params={})
      mime_type = self.mime_type(type)
      fail "Unknown media type: %p" % type if mime_type.nil?
      if params.any?
        params = params.collect { |kv| "%s=%s" % kv }.join(', ')
        response['Content-Type'] = [mime_type, params].join(";")
      else
        response['Content-Type'] = mime_type
      end
    end

    # Set the Content-Disposition to "attachment" with the specified filename,
    # instructing the user agents to prompt to save.
    def attachment(filename=nil)
      response['Content-Disposition'] = 'attachment'
      if filename
        params = '; filename="%s"' % File.basename(filename)
        response['Content-Disposition'] << params
      end
    end

    # Use the contents of the file at +path+ as the response body.
    def send_file(path, opts={})
      stat = File.stat(path)
      last_modified stat.mtime

      content_type mime_type(opts[:type]) ||
        mime_type(File.extname(path)) ||
        response['Content-Type'] ||
        'application/octet-stream'

      response['Content-Length'] ||= (opts[:length] || stat.size).to_s

      if opts[:disposition] == 'attachment' || opts[:filename]
        attachment opts[:filename] || path
      elsif opts[:disposition] == 'inline'
        response['Content-Disposition'] = 'inline'
      end

      halt StaticFile.open(path, 'rb')
    rescue Errno::ENOENT
      not_found
    end

    # Rack response body used to deliver static files. The file contents are
    # generated iteratively in 8K chunks.
    class StaticFile < ::File #:nodoc:
      alias_method :to_path, :path
      def each
        rewind
        while buf = read(8192)
          yield buf
        end
      end
    end

    # Specify response freshness policy for HTTP caches (Cache-Control header).
    # Any number of non-value directives (:public, :private, :no_cache,
    # :no_store, :must_revalidate, :proxy_revalidate) may be passed along with
    # a Hash of value directives (:max_age, :min_stale, :s_max_age).
    #
    #   cache_control :public, :must_revalidate, :max_age => 60
    #   => Cache-Control: public, must-revalidate, max-age=60
    #
    # See RFC 2616 / 14.9 for more on standard cache control directives:
    # http://tools.ietf.org/html/rfc2616#section-14.9.1
    def cache_control(*values)
      if values.last.kind_of?(Hash)
        hash = values.pop
        hash.reject! { |k,v| v == false }
        hash.reject! { |k,v| values << k if v == true }
      else
        hash = {}
      end

      values = values.map { |value| value.to_s.tr('_','-') }
      hash.each { |k,v| values << [k.to_s.tr('_', '-'), v].join('=') }

      response['Cache-Control'] = values.join(', ') if values.any?
    end

    # Set the Expires header and Cache-Control/max-age directive. Amount
    # can be an integer number of seconds in the future or a Time object
    # indicating when the response should be considered "stale". The remaining
    # "values" arguments are passed to the #cache_control helper:
    #
    #   expires 500, :public, :must_revalidate
    #   => Cache-Control: public, must-revalidate, max-age=60
    #   => Expires: Mon, 08 Jun 2009 08:50:17 GMT
    #
    def expires(amount, *values)
      values << {} unless values.last.kind_of?(Hash)

      if amount.respond_to?(:to_time)
        max_age = amount.to_time - Time.now
        time = amount.to_time
      else
        max_age = amount
        time = Time.now + amount
      end

      values.last.merge!(:max_age => max_age)
      cache_control(*values)

      response['Expires'] = time.httpdate
    end

    # Set the last modified time of the resource (HTTP 'Last-Modified' header)
    # and halt if conditional GET matches. The +time+ argument is a Time,
    # DateTime, or other object that responds to +to_time+.
    #
    # When the current request includes an 'If-Modified-Since' header that
    # matches the time specified, execution is immediately halted with a
    # '304 Not Modified' response.
    def last_modified(time)
      return unless time
      time = time.to_time if time.respond_to?(:to_time)
      time = time.httpdate if time.respond_to?(:httpdate)
      response['Last-Modified'] = time
      halt 304 if time == request.env['HTTP_IF_MODIFIED_SINCE']
      time
    end

    # Set the response entity tag (HTTP 'ETag' header) and halt if conditional
    # GET matches. The +value+ argument is an identifier that uniquely
    # identifies the current version of the resource. The +kind+ argument
    # indicates whether the etag should be used as a :strong (default) or :weak
    # cache validator.
    #
    # When the current request includes an 'If-None-Match' header with a
    # matching etag, execution is immediately halted. If the request method is
    # GET or HEAD, a '304 Not Modified' response is sent.
    def etag(value, kind=:strong)
      raise TypeError, ":strong or :weak expected" if ![:strong,:weak].include?(kind)
      value = '"%s"' % value
      value = 'W/' + value if kind == :weak
      response['ETag'] = value

      # Conditional GET check
      if etags = env['HTTP_IF_NONE_MATCH']
        etags = etags.split(/\s*,\s*/)
        halt 304 if etags.include?(value) || etags.include?('*')
      end
    end

    ## Sugar for redirect (example:  redirect back)
    def back ; request.referer ; end

  end

  # Template rendering methods. Each method takes the name of a template
  # to render as a Symbol and returns a String with the rendered output,
  # as well as an optional hash with additional options.
  #
  # `template` is either the name or path of the template as symbol
  # (Use `:'subdir/myview'` for views in subdirectories), or a string
  # that will be rendered.
  #
  # Possible options are:
  #   :layout       If set to false, no layout is rendered, otherwise
  #                 the specified layout is used (Ignored for `sass` and `less`)
  #   :locals       A hash with local variables that should be available
  #                 in the template
  module Templates
    include Tilt::CompileSite

    def erb(template, options={}, locals={})
      options[:outvar] = '@_out_buf'
      render :erb, template, options, locals
    end

    def erubis(template, options={}, locals={})
      options[:outvar] = '@_out_buf'
      render :erubis, template, options, locals
    end

    def haml(template, options={}, locals={})
      render :haml, template, options, locals
    end

    def sass(template, options={}, locals={})
      options[:layout] = false
      render :sass, template, options, locals
    end

    def less(template, options={}, locals={})
      options[:layout] = false
      render :less, template, options, locals
    end

    def builder(template=nil, options={}, locals={}, &block)
      options, template = template, nil if template.is_a?(Hash)
      template = Proc.new { block } if template.nil?
      render :builder, template, options, locals
    end

  private
    def render(engine, data, options={}, locals={}, &block)
      # merge app-level options
      options = settings.send(engine).merge(options) if settings.respond_to?(engine)

      # extract generic options
      locals = options.delete(:locals) || locals || {}
      views = options.delete(:views) || settings.views || "./views"
      layout = options.delete(:layout)
      layout = :layout if layout.nil? || layout == true

      # compile and render template
      template = compile_template(engine, data, options, views)
      output = template.render(self, locals, &block)

      # render layout
      if layout
        begin
          options = options.merge(:views => views, :layout => false)
          output = render(engine, layout, options, locals) { output }
        rescue Errno::ENOENT
        end
      end

      output
    end

    def compile_template(engine, data, options, views)
      @template_cache.fetch engine, data, options do
        template = Tilt[engine]
        raise "Template engine not found: #{engine}" if template.nil?

        case
        when data.is_a?(Symbol)
          body, path, line = self.class.templates[data]
          if body
            body = body.call if body.respond_to?(:call)
            template.new(path, line.to_i, options) { body }
          else
            path = ::File.join(views, "#{data}.#{engine}")
            template.new(path, 1, options)
          end
        when data.is_a?(Proc) || data.is_a?(String)
          body = data.is_a?(String) ? Proc.new { data } : data
          path, line = self.class.caller_locations.first
          template.new(path, line.to_i, options, &body)
        else
          raise ArgumentError
        end
      end
    end
  end

  # Base class for all Sinatra applications and middleware.
  class Base
    include Rack::Utils
    include Helpers
    include Templates

    attr_accessor :app

    def initialize(app=nil)
      @app = app
      @template_cache = Tilt::Cache.new
      yield self if block_given?
    end

    # Rack call interface.
    def call(env)
      dup.call!(env)
    end

    attr_accessor :env, :request, :response, :params

    def call!(env)
      @env      = env
      @request  = Request.new(env)
      @response = Response.new
      @params   = indifferent_params(@request.params)
      @template_cache.clear if settings.reload_templates

      invoke { dispatch! }
      invoke { error_block!(response.status) }

      status, header, body = @response.finish

      # Never produce a body on HEAD requests. Do retain the Content-Length
      # unless it's "0", in which case we assume it was calculated erroneously
      # for a manual HEAD response and remove it entirely.
      if @env['REQUEST_METHOD'] == 'HEAD'
        body = []
        header.delete('Content-Length') if header['Content-Length'] == '0'
      end

      [status, header, body]
    end

    # Access settings defined with Base.set.
    def settings
      self.class
    end
    alias_method :options, :settings

    # Exit the current block, halts any further processing
    # of the request, and returns the specified response.
    def halt(*response)
      response = response.first if response.length == 1
      throw :halt, response
    end

    # Pass control to the next matching route.
    # If there are no more matching routes, Sinatra will
    # return a 404 response.
    def pass(&block)
      throw :pass, block
    end

    # Forward the request to the downstream app -- middleware only.
    def forward
      fail "downstream app not set" unless @app.respond_to? :call
      status, headers, body = @app.call(@request.env)
      @response.status = status
      @response.body = body
      @response.headers.merge! headers
      nil
    end

  private
    # Run before filters defined on the class and all superclasses.
    def before_filter!(base=self.class)
      before_filter!(base.superclass) if base.superclass.respond_to?(:before_filters)
      base.before_filters.each { |block| instance_eval(&block) }
    end

    # Run after filters defined on the class and all superclasses.
    def after_filter!(base=self.class)
      after_filter!(base.superclass) if base.superclass.respond_to?(:after_filters)
      base.after_filters.each { |block| instance_eval(&block) }
    end

    # Run routes defined on the class and all superclasses.
    def route!(base=self.class, pass_block=nil)
      if routes = base.routes[@request.request_method]
        original_params = @params
        path            = unescape(@request.path_info)

        routes.each do |pattern, keys, conditions, block|
          if match = pattern.match(path)
            values = match.captures.to_a
            params =
              if keys.any?
                keys.zip(values).inject({}) do |hash,(k,v)|
                  if k == 'splat'
                    (hash[k] ||= []) << v
                  else
                    hash[k] = v
                  end
                  hash
                end
              elsif values.any?
                {'captures' => values}
              else
                {}
              end
            @params = original_params.merge(params)
            @block_params = values

            pass_block = catch(:pass) do
              conditions.each { |cond|
                throw :pass if instance_eval(&cond) == false }
              route_eval(&block)
            end
          end
        end

        @params = original_params
      end

      # Run routes defined in superclass.
      if base.superclass.respond_to?(:routes)
        route! base.superclass, pass_block
        return
      end

      route_eval(&pass_block) if pass_block

      route_missing
    end

    # Run a route block and throw :halt with the result.
    def route_eval(&block)
      throw :halt, instance_eval(&block)
    end

    # No matching route was found or all routes passed. The default
    # implementation is to forward the request downstream when running
    # as middleware (@app is non-nil); when no downstream app is set, raise
    # a NotFound exception. Subclasses can override this method to perform
    # custom route miss logic.
    def route_missing
      if @app
        forward
      else
        raise NotFound
      end
    end

    # Attempt to serve static files from public directory. Throws :halt when
    # a matching file is found, returns nil otherwise.
    def static!
      return if (public_dir = settings.public).nil?
      public_dir = File.expand_path(public_dir)

      path = File.expand_path(public_dir + unescape(request.path_info))
      return if path[0, public_dir.length] != public_dir
      return unless File.file?(path)

      env['sinatra.static_file'] = path
      send_file path, :disposition => nil
    end

    # Enable string or symbol key access to the nested params hash.
    def indifferent_params(params)
      params = indifferent_hash.merge(params)
      params.each do |key, value|
        next unless value.is_a?(Hash)
        params[key] = indifferent_params(value)
      end
    end

    def indifferent_hash
      Hash.new {|hash,key| hash[key.to_s] if Symbol === key }
    end

    # Run the block with 'throw :halt' support and apply result to the response.
    def invoke(&block)
      res = catch(:halt) { instance_eval(&block) }
      return if res.nil?

      case
      when res.respond_to?(:to_str)
        @response.body = [res]
      when res.respond_to?(:to_ary)
        res = res.to_ary
        if Fixnum === res.first
          if res.length == 3
            @response.status, headers, body = res
            @response.body = body if body
            headers.each { |k, v| @response.headers[k] = v } if headers
          elsif res.length == 2
            @response.status = res.first
            @response.body   = res.last
          else
            raise TypeError, "#{res.inspect} not supported"
          end
        else
          @response.body = res
        end
      when res.respond_to?(:each)
        @response.body = res
      when (100...599) === res
        @response.status = res
      end

      res
    end

    # Dispatch a request with error handling.
    def dispatch!
      static! if settings.static? && (request.get? || request.head?)
      before_filter!
      route!
    rescue NotFound => boom
      handle_not_found!(boom)
    rescue ::Exception => boom
      handle_exception!(boom)
    ensure
      after_filter! unless env['sinatra.static_file']
    end

    def handle_not_found!(boom)
      @env['sinatra.error']          = boom
      @response.status               = 404
      @response.headers['X-Cascade'] = 'pass'
      @response.body                 = ['<h1>Not Found</h1>']
      error_block! boom.class, NotFound
    end

    def handle_exception!(boom)
      @env['sinatra.error'] = boom

      dump_errors!(boom) if settings.dump_errors?
      raise boom         if settings.show_exceptions?

      @response.status = 500
      if res = error_block!(boom.class)
        res
      elsif settings.raise_errors?
        raise boom
      else
        error_block!(Exception)
      end
    end

    # Find an custom error block for the key(s) specified.
    def error_block!(*keys)
      keys.each do |key|
        base = self.class
        while base.respond_to?(:errors)
          if block = base.errors[key]
            # found a handler, eval and return result
            return instance_eval(&block)
          else
            base = base.superclass
          end
        end
      end
      nil
    end

    def dump_errors!(boom)
      msg = ["#{boom.class} - #{boom.message}:",
        *boom.backtrace].join("\n ")
      @env['rack.errors'].puts(msg)
    end

    class << self
      attr_reader :routes, :before_filters, :after_filters, :templates, :errors

      def reset!
        @conditions     = []
        @routes         = {}
        @before_filters = []
        @after_filters  = []
        @errors         = {}
        @middleware     = []
        @prototype      = nil
        @extensions     = []

        if superclass.respond_to?(:templates)
          @templates = Hash.new { |hash,key| superclass.templates[key] }
        else
          @templates = {}
        end
      end

      # Extension modules registered on this class and all superclasses.
      def extensions
        if superclass.respond_to?(:extensions)
          (@extensions + superclass.extensions).uniq
        else
          @extensions
        end
      end

      # Middleware used in this class and all superclasses.
      def middleware
        if superclass.respond_to?(:middleware)
          superclass.middleware + @middleware
        else
          @middleware
        end
      end

      # Sets an option to the given value.  If the value is a proc,
      # the proc will be called every time the option is accessed.
      def set(option, value=self, &block)
        raise ArgumentError if block && value != self
        value = block if block
        if value.kind_of?(Proc)
          metadef(option, &value)
          metadef("#{option}?") { !!__send__(option) }
          metadef("#{option}=") { |val| metadef(option, &Proc.new{val}) }
        elsif value == self && option.respond_to?(:to_hash)
          option.to_hash.each { |k,v| set(k, v) }
        elsif respond_to?("#{option}=")
          __send__ "#{option}=", value
        else
          set option, Proc.new{value}
        end
        self
      end

      # Same as calling `set :option, true` for each of the given options.
      def enable(*opts)
        opts.each { |key| set(key, true) }
      end

      # Same as calling `set :option, false` for each of the given options.
      def disable(*opts)
        opts.each { |key| set(key, false) }
      end

      # Define a custom error handler. Optionally takes either an Exception
      # class, or an HTTP status code to specify which errors should be
      # handled.
      def error(codes=Exception, &block)
        Array(codes).each { |code| @errors[code] = block }
      end

      # Sugar for `error(404) { ... }`
      def not_found(&block)
        error 404, &block
      end

      # Define a named template. The block must return the template source.
      def template(name, &block)
        filename, line = caller_locations.first
        templates[name] = [block, filename, line.to_i]
      end

      # Define the layout template. The block must return the template source.
      def layout(name=:layout, &block)
        template name, &block
      end

      # Load embeded templates from the file; uses the caller's __FILE__
      # when no file is specified.
      def inline_templates=(file=nil)
        file = (file.nil? || file == true) ? caller_files.first : file

        begin
          app, data =
            ::IO.read(file).gsub("\r\n", "\n").split(/^__END__$/, 2)
        rescue Errno::ENOENT
          app, data = nil
        end

        if data
          lines = app.count("\n") + 1
          template = nil
          data.each_line do |line|
            lines += 1
            if line =~ /^@@\s*(.*)/
              template = ''
              templates[$1.to_sym] = [template, file, lines]
            elsif template
              template << line
            end
          end
        end
      end

      # Lookup or register a mime type in Rack's mime registry.
      def mime_type(type, value=nil)
        return type if type.nil? || type.to_s.include?('/')
        type = ".#{type}" unless type.to_s[0] == ?.
        return Rack::Mime.mime_type(type, nil) unless value
        Rack::Mime::MIME_TYPES[type] = value
      end

      # Define a before filter; runs before all requests within the same
      # context as route handlers and may access/modify the request and
      # response.
      def before(&block)
        @before_filters << block
      end

      # Define an after filter; runs after all requests within the same
      # context as route handlers and may access/modify the request and
      # response.
      def after(&block)
        @after_filters << block
      end

      # Add a route condition. The route is considered non-matching when the
      # block returns false.
      def condition(&block)
        @conditions << block
      end

   private
      def host_name(pattern)
        condition { pattern === request.host }
      end

      def user_agent(pattern)
        condition {
          if request.user_agent =~ pattern
            @params[:agent] = $~[1..-1]
            true
          else
            false
          end
        }
      end
      alias_method :agent, :user_agent

      def provides(*types)
        types = [types] unless types.kind_of? Array
        types.map!{|t| mime_type(t)}

        condition {
          matching_types = (request.accept & types)
          unless matching_types.empty?
            response.headers['Content-Type'] = matching_types.first
            true
          else
            false
          end
        }
      end

    public
      # Defining a `GET` handler also automatically defines
      # a `HEAD` handler.
      def get(path, opts={}, &block)
        conditions = @conditions.dup
        route('GET', path, opts, &block)

        @conditions = conditions
        route('HEAD', path, opts, &block)
      end

      def put(path, opts={}, &bk);    route 'PUT',    path, opts, &bk end
      def post(path, opts={}, &bk);   route 'POST',   path, opts, &bk end
      def delete(path, opts={}, &bk); route 'DELETE', path, opts, &bk end
      def head(path, opts={}, &bk);   route 'HEAD',   path, opts, &bk end

    private
      def route(verb, path, options={}, &block)
        # Because of self.options.host
        host_name(options.delete(:bind)) if options.key?(:host)

        options.each {|option, args| send(option, *args)}

        pattern, keys = compile(path)
        conditions, @conditions = @conditions, []

        define_method "#{verb} #{path}", &block
        unbound_method = instance_method("#{verb} #{path}")
        block =
          if block.arity != 0
            proc { unbound_method.bind(self).call(*@block_params) }
          else
            proc { unbound_method.bind(self).call }
          end

        invoke_hook(:route_added, verb, path, block)

        (@routes[verb] ||= []).
          push([pattern, keys, conditions, block]).last
      end

      def invoke_hook(name, *args)
        extensions.each { |e| e.send(name, *args) if e.respond_to?(name) }
      end

      def compile(path)
        keys = []
        if path.respond_to? :to_str
          special_chars = %w{. + ( )}
          pattern =
            path.to_str.gsub(/((:\w+)|[\*#{special_chars.join}])/) do |match|
              case match
              when "*"
                keys << 'splat'
                "(.*?)"
              when *special_chars
                Regexp.escape(match)
              else
                keys << $2[1..-1]
                "([^/?&#]+)"
              end
            end
          [/^#{pattern}$/, keys]
        elsif path.respond_to?(:keys) && path.respond_to?(:match)
          [path, path.keys]
        elsif path.respond_to? :match
          [path, keys]
        else
          raise TypeError, path
        end
      end

    public
      # Makes the methods defined in the block and in the Modules given
      # in `extensions` available to the handlers and templates
      def helpers(*extensions, &block)
        class_eval(&block)  if block_given?
        include(*extensions) if extensions.any?
      end

      def register(*extensions, &block)
        extensions << Module.new(&block) if block_given?
        @extensions += extensions
        extensions.each do |extension|
          extend extension
          extension.registered(self) if extension.respond_to?(:registered)
        end
      end

      def development?; environment == :development end
      def production?;  environment == :production  end
      def test?;        environment == :test        end

      # Set configuration options for Sinatra and/or the app.
      # Allows scoping of settings for certain environments.
      def configure(*envs, &block)
        yield self if envs.empty? || envs.include?(environment.to_sym)
      end

      # Use the specified Rack middleware
      def use(middleware, *args, &block)
        @prototype = nil
        @middleware << [middleware, args, block]
      end

      # Run the Sinatra app as a self-hosted server using
      # Thin, Mongrel or WEBrick (in that order)
      def run!(options={})
        set options
        handler      = detect_rack_handler
        handler_name = handler.name.gsub(/.*::/, '')
        puts "== Sinatra/#{Sinatra::VERSION} has taken the stage " +
          "on #{port} for #{environment} with backup from #{handler_name}" unless handler_name =~/cgi/i
        handler.run self, :Host => bind, :Port => port do |server|
          trap(:INT) do
            ## Use thins' hard #stop! if available, otherwise just #stop
            server.respond_to?(:stop!) ? server.stop! : server.stop
            puts "\n== Sinatra has ended his set (crowd applauds)" unless handler_name =~/cgi/i
          end
          set :running, true
        end
      rescue Errno::EADDRINUSE => e
        puts "== Someone is already performing on port #{port}!"
      end

      # The prototype instance used to process requests.
      def prototype
        @prototype ||= new
      end

      # Create a new instance of the class fronted by its middleware
      # pipeline. The object is guaranteed to respond to #call but may not be
      # an instance of the class new was called on.
      def new(*args, &bk)
        builder = Rack::Builder.new
        builder.use Rack::Session::Cookie if sessions?
        builder.use Rack::CommonLogger    if logging?
        builder.use Rack::MethodOverride  if method_override?
        builder.use ShowExceptions        if show_exceptions?
        middleware.each { |c,a,b| builder.use(c, *a, &b) }

        builder.run super
        builder.to_app
      end

      def call(env)
        synchronize { prototype.call(env) }
      end

    private
      def detect_rack_handler
        servers = Array(self.server)
        servers.each do |server_name|
          begin
            return Rack::Handler.get(server_name.downcase)
          rescue LoadError
          rescue NameError
          end
        end
        fail "Server handler (#{servers.join(',')}) not found."
      end

      def inherited(subclass)
        subclass.reset!
        super
      end

      @@mutex = Mutex.new
      def synchronize(&block)
        if lock?
          @@mutex.synchronize(&block)
        else
          yield
        end
      end

      def metadef(message, &block)
        (class << self; self; end).
          send :define_method, message, &block
      end

    public
      CALLERS_TO_IGNORE = [
        /\/sinatra(\/(base|main|showexceptions))?\.rb$/, # all sinatra code
        /lib\/tilt.*\.rb$/,    # all tilt code
        /\(.*\)/,              # generated code
        /custom_require\.rb$/, # rubygems require hacks
        /active_support/,      # active_support require hacks
      ]

      # add rubinius (and hopefully other VM impls) ignore patterns ...
      CALLERS_TO_IGNORE.concat(RUBY_IGNORE_CALLERS) if defined?(RUBY_IGNORE_CALLERS)

      # Like Kernel#caller but excluding certain magic entries and without
      # line / method information; the resulting array contains filenames only.
      def caller_files
        caller_locations.
          map { |file,line| file }
      end

      def caller_locations
        caller(1).
          map    { |line| line.split(/:(?=\d|in )/)[0,2] }.
          reject { |file,line| CALLERS_TO_IGNORE.any? { |pattern| file =~ pattern } }
      end
    end

    reset!

    set :environment, (ENV['RACK_ENV'] || :development).to_sym
    set :raise_errors, Proc.new { test? }
    set :dump_errors, Proc.new { !test? }
    set :show_exceptions, Proc.new { development? }
    set :sessions, false
    set :logging, false
    set :method_override, false

    class << self
      alias_method :methodoverride?, :method_override?
      alias_method :methodoverride=, :method_override=
    end

    set :run, false                       # start server via at-exit hook?
    set :running, false                   # is the built-in server running now?
    set :server, %w[thin mongrel webrick]
    set :bind, '0.0.0.0'
    set :port, 4567

    set :app_file, nil
    set :root, Proc.new { app_file && File.expand_path(File.dirname(app_file)) }
    set :views, Proc.new { root && File.join(root, 'views') }
    set :reload_templates, Proc.new { development? }
    set :lock, false

    set :public, Proc.new { root && File.join(root, 'public') }
    set :static, Proc.new { self.public && File.exist?(self.public) }

    error ::Exception do
      response.status = 500
      content_type 'text/html'
      '<h1>Internal Server Error</h1>'
    end

    configure :development do
      get '/__sinatra__/:image.png' do
        filename = File.dirname(__FILE__) + "/images/#{params[:image]}.png"
        content_type :png
        send_file filename
      end

      error NotFound do
        content_type 'text/html'

        (<<-HTML).gsub(/^ {8}/, '')
        <!DOCTYPE html>
        <html>
        <head>
          <style type="text/css">
          body { text-align:center;font-family:helvetica,arial;font-size:22px;
            color:#888;margin:20px}
          #c {margin:0 auto;width:500px;text-align:left}
          </style>
        </head>
        <body>
          <h2>Sinatra doesn't know this ditty.</h2>
          <img src='/__sinatra__/404.png'>
          <div id="c">
            Try this:
            <pre>#{request.request_method.downcase} '#{request.path_info}' do\n  "Hello World"\nend</pre>
          </div>
        </body>
        </html>
        HTML
      end
    end
  end

  # Execution context for classic style (top-level) applications. All
  # DSL methods executed on main are delegated to this class.
  #
  # The Application class should not be subclassed, unless you want to
  # inherit all settings, routes, handlers, and error pages from the
  # top-level. Subclassing Sinatra::Base is heavily recommended for
  # modular applications.
  class Application < Base
    set :logging, Proc.new { ! test? }
    set :method_override, true
    set :run, Proc.new { ! test? }

    def self.register(*extensions, &block) #:nodoc:
      added_methods = extensions.map {|m| m.public_instance_methods }.flatten
      Delegator.delegate(*added_methods)
      super(*extensions, &block)
    end
  end

  # Sinatra delegation mixin. Mixing this module into an object causes all
  # methods to be delegated to the Sinatra::Application class. Used primarily
  # at the top-level.
  module Delegator #:nodoc:
    def self.delegate(*methods)
      methods.each do |method_name|
        eval <<-RUBY, binding, '(__DELEGATE__)', 1
          def #{method_name}(*args, &b)
            ::Sinatra::Application.send(#{method_name.inspect}, *args, &b)
          end
          private #{method_name.inspect}
        RUBY
      end
    end

    delegate :get, :put, :post, :delete, :head, :template, :layout,
             :before, :after, :error, :not_found, :configure, :set, :mime_type,
             :enable, :disable, :use, :development?, :test?, :production?,
             :helpers, :settings
  end

  # Create a new Sinatra application. The block is evaluated in the new app's
  # class scope.
  def self.new(base=Base, options={}, &block)
    base = Class.new(base)
    base.send :class_eval, &block if block_given?
    base
  end

  # Extend the top-level DSL with the modules provided.
  def self.register(*extensions, &block)
    Application.register(*extensions, &block)
  end

  # Include the helper modules provided in Sinatra's request context.
  def self.helpers(*extensions, &block)
    Application.helpers(*extensions, &block)
  end
end
