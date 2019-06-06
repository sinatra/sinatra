# coding: utf-8
# frozen_string_literal: true

# external dependencies
require 'rack'
require 'tilt'
require 'rack/protection'
require 'mustermann'
require 'mustermann/sinatra'
require 'mustermann/regular'

# stdlib dependencies
require 'thread'
require 'time'
require 'uri'

# other files we need
require 'sinatra/indifferent_hash'
require 'sinatra/show_exceptions'
require 'sinatra/version'
require 'sinatra/errors'
require 'sinatra/helpers'
require 'sinatra/templates'
require 'sinatra/request'
require 'sinatra/response'
require 'sinatra/extended_rack'
require 'sinatra/common_logger'

module Sinatra
  # Base class for all Sinatra applications and middleware.
  class Base
    include Rack::Utils
    include Helpers
    include Templates

    URI_INSTANCE = URI::Parser.new

    attr_accessor :app, :env, :request, :response, :params
    attr_reader   :template_cache

    def initialize(app = nil)
      super()
      @app = app
      @template_cache = Tilt::Cache.new
      @pinned_response = nil # whether a before! filter pinned the content-type
      yield self if block_given?
    end

    # Rack call interface.
    def call(env)
      dup.call!(env)
    end

    def call!(env) # :nodoc:
      @env      = env
      @params   = IndifferentHash.new
      @request  = Request.new(env)
      @response = Response.new
      @pinned_response = nil
      template_cache.clear if settings.reload_templates

      invoke { dispatch! }
      invoke { error_block!(response.status) } unless @env['sinatra.error']

      unless @response['Content-Type']
        if Array === body && body[0].respond_to?(:content_type)
          content_type body[0].content_type
        elsif default = settings.default_content_type
          content_type default
        end
      end

      @response.finish
    end

    # Access settings defined with Base.set.
    def self.settings
      self
    end

    # Access settings defined with Base.set.
    def settings
      self.class.settings
    end

    def options
      warn "Sinatra::Base#options is deprecated and will be removed, " \
        "use #settings instead."
      settings
    end

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
      status, headers, body = @app.call env
      @response.status = status
      @response.body = body
      @response.headers.merge! headers
      nil
    end

    private

    # Run filters defined on the class and all superclasses.
    # Accepts an optional block to call after each filter is applied.
    def filter!(type, base = settings, &block)
      filter!(type, base.superclass, &block) if base.superclass.respond_to?(:filters)
      base.filters[type].each do |args|
        result = process_route(*args)
        block.call(result) if block_given?
      end
    end

    # Run routes defined on the class and all superclasses.
    def route!(base = settings, pass_block = nil)
      if routes = base.routes[@request.request_method]
        routes.each do |pattern, conditions, block|
          response.delete_header('Content-Type') unless @pinned_response

          returned_pass_block = process_route(pattern, conditions) do |*args|
            env['sinatra.route'] = "#{@request.request_method} #{pattern}"
            route_eval { block[*args] }
          end

          # don't wipe out pass_block in superclass
          pass_block = returned_pass_block if returned_pass_block
        end
      end

      # Run routes defined in superclass.
      if base.superclass.respond_to?(:routes)
        return route!(base.superclass, pass_block)
      end

      route_eval(&pass_block) if pass_block
      route_missing
    end

    # Run a route block and throw :halt with the result.
    def route_eval
      throw :halt, yield
    end

    # If the current request matches pattern and conditions, fill params
    # with keys and call the given block.
    # Revert params afterwards.
    #
    # Returns pass block.
    def process_route(pattern, conditions, block = nil, values = [])
      route = @request.path_info
      route = '/' if route.empty? and not settings.empty_path_info?
      route = route[0..-2] if !settings.strict_paths? && route != '/' && route.end_with?('/')
      return unless params = pattern.params(route)

      params.delete("ignore") # TODO: better params handling, maybe turn it into "smart" object or detect changes
      force_encoding(params)
      @params = @params.merge(params) if params.any?

      regexp_exists = pattern.is_a?(Mustermann::Regular) || (pattern.respond_to?(:patterns) && pattern.patterns.any? {|subpattern| subpattern.is_a?(Mustermann::Regular)} )
      if regexp_exists
        captures           = pattern.match(route).captures.map { |c| URI_INSTANCE.unescape(c) if c }
        values            += captures
        @params[:captures] = force_encoding(captures) unless captures.nil? || captures.empty?
      else
        values += params.values.flatten
      end

      catch(:pass) do
        conditions.each { |c| throw :pass if c.bind(self).call == false }
        block ? block[self, values] : yield(self, values)
      end
    rescue
      @env['sinatra.error.params'] = @params
      raise
    ensure
      params ||= {}
      params.each { |k, _| @params.delete(k) } unless @env['sinatra.error.params']
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
        raise NotFound, "#{request.request_method} #{request.path_info}"
      end
    end

    # Attempt to serve static files from public directory. Throws :halt when
    # a matching file is found, returns nil otherwise.
    def static!(options = {})
      return if (public_dir = settings.public_folder).nil?
      path = "#{public_dir}#{URI_INSTANCE.unescape(request.path_info)}"
      return unless valid_path?(path)

      path = File.expand_path(path)
      return unless File.file?(path)

      env['sinatra.static_file'] = path
      cache_control(*settings.static_cache_control) if settings.static_cache_control?
      send_file path, options.merge(:disposition => nil)
    end

    # Run the block with 'throw :halt' support and apply result to the response.
    def invoke
      res = catch(:halt) { yield }

      res = [res] if Integer === res or String === res
      if Array === res and Integer === res.first
        res = res.dup
        status(res.shift)
        body(res.pop)
        headers(*res)
      elsif res.respond_to? :each
        body res
      end
      nil # avoid double setting the same response tuple twice
    end

    # Dispatch a request with error handling.
    def dispatch!
      # Avoid passing frozen string in force_encoding
      @params.merge!(@request.params).each do |key, val|
        next unless val.respond_to?(:force_encoding)
        val = val.dup if val.frozen?
        @params[key] = force_encoding(val)
      end

      invoke do
        static! if settings.static? && (request.get? || request.head?)
        filter! :before do
          @pinned_response = !response['Content-Type'].nil?
        end
        route!
      end
    rescue ::Exception => boom
      invoke { handle_exception!(boom) }
    ensure
      begin
        filter! :after unless env['sinatra.static_file']
      rescue ::Exception => boom
        invoke { handle_exception!(boom) } unless @env['sinatra.error']
      end
    end

    # Error handling during requests.
    def handle_exception!(boom)
      if error_params = @env['sinatra.error.params']
        @params = @params.merge(error_params)
      end
      @env['sinatra.error'] = boom

      if boom.respond_to? :http_status and boom.http_status.between? 400, 599
        status(boom.http_status)
      elsif settings.use_code? and boom.respond_to? :code and boom.code.between? 400, 599
        status(boom.code)
      else
        status(500)
      end

      if server_error?
        dump_errors! boom if settings.dump_errors?
        raise boom if settings.show_exceptions? and settings.show_exceptions != :after_handler
      elsif not_found?
        headers['X-Cascade'] = 'pass' if settings.x_cascade?
      end

      if res = error_block!(boom.class, boom) || error_block!(status, boom)
        return res
      end

      if not_found? || bad_request?
        if boom.message && boom.message != boom.class.name
          body Rack::Utils.escape_html(boom.message)
        else
          content_type 'text/html'
          body '<h1>' + (not_found? ? 'Not Found' : 'Bad Request') + '</h1>'
        end
      end

      return unless server_error?
      raise boom if settings.raise_errors? or settings.show_exceptions?
      error_block! Exception, boom
    end

    # Find an custom error block for the key(s) specified.
    def error_block!(key, *block_params)
      base = settings
      while base.respond_to?(:errors)
        next base = base.superclass unless args_array = base.errors[key]
        args_array.reverse_each do |args|
          first = args == args_array.first
          args += [block_params]
          resp = process_route(*args)
          return resp unless resp.nil? && !first
        end
      end
      return false unless key.respond_to? :superclass and key.superclass < Exception
      error_block!(key.superclass, *block_params)
    end

    def dump_errors!(boom)
      msg = ["#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} - #{boom.class} - #{boom.message}:", *boom.backtrace].join("\n\t")
      @env['rack.errors'].puts(msg)
    end

    class << self
      CALLERS_TO_IGNORE = [ # :nodoc:
        /\/sinatra(\/(base|main|show_exceptions))?\.rb$/,   # all sinatra code
        /lib\/tilt.*\.rb$/,                                 # all tilt code
        /^\(.*\)$/,                                         # generated code
        /rubygems\/(custom|core_ext\/kernel)_require\.rb$/, # rubygems require hacks
        /active_support/,                                   # active_support require hacks
        /bundler(\/(?:runtime|inline))?\.rb/,               # bundler require hacks
        /<internal:/,                                       # internal in ruby >= 1.9.2
        /src\/kernel\/bootstrap\/[A-Z]/                     # maglev kernel files
      ]

      # contrary to what the comment said previously, rubinius never supported this
      if defined?(RUBY_IGNORE_CALLERS)
        warn "RUBY_IGNORE_CALLERS is deprecated and will no longer be supported by Sinatra 2.0"
        CALLERS_TO_IGNORE.concat(RUBY_IGNORE_CALLERS)
      end

      attr_reader :routes, :filters, :templates, :errors

      # Removes all routes, filters, middleware and extension hooks from the
      # current class (not routes/filters/... defined by its superclass).
      def reset!
        @conditions     = []
        @routes         = {}
        @filters        = {:before => [], :after => []}
        @errors         = {}
        @middleware     = []
        @prototype      = nil
        @extensions     = []

        if superclass.respond_to?(:templates)
          @templates = Hash.new { |hash, key| superclass.templates[key] }
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
      def set(option, value = (not_set = true), ignore_setter = false, &block)
        raise ArgumentError if block and !not_set
        value, not_set = block, false if block

        if not_set
          raise ArgumentError unless option.respond_to?(:each)
          option.each { |k,v| set(k, v) }
          return self
        end

        if respond_to?("#{option}=") and not ignore_setter
          return __send__("#{option}=", value)
        end

        setter = proc { |val| set option, val, true }
        getter = proc { value }

        case value
        when Proc
          getter = value
        when Symbol, Integer, FalseClass, TrueClass, NilClass
          getter = value.inspect
        when Hash
          setter = proc do |val|
            val = value.merge val if Hash === val
            set option, val, true
          end
        end

        define_singleton("#{option}=", setter)
        define_singleton(option, getter)
        define_singleton("#{option}?", "!!#{option}") unless method_defined? "#{option}?"
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
      def error(*codes, &block)
        args  = compile! "ERROR", /.*/, block
        codes = codes.flat_map(&method(:Array))
        codes << Exception if codes.empty?
        codes << Sinatra::NotFound if codes.include?(404)
        codes.each { |c| (@errors[c] ||= []) << args }
      end

      # Sugar for `error(404) { ... }`
      def not_found(&block)
        error(404, &block)
      end

      # Define a named template. The block must return the template source.
      def template(name, &block)
        filename, line = caller_locations.first
        templates[name] = [block, filename, line.to_i]
      end

      # Define the layout template. The block must return the template source.
      def layout(name = :layout, &block)
        template name, &block
      end

      # Load embedded templates from the file; uses the caller's __FILE__
      # when no file is specified.
      def inline_templates=(file = nil)
        file = (file.nil? || file == true) ? (caller_files.first || File.expand_path($0)) : file

        begin
          io = ::IO.respond_to?(:binread) ? ::IO.binread(file) : ::IO.read(file)
          app, data = io.gsub("\r\n", "\n").split(/^__END__$/, 2)
        rescue Errno::ENOENT
          app, data = nil
        end

        if data
          if app and app =~ /([^\n]*\n)?#[^\n]*coding: *(\S+)/m
            encoding = $2
          else
            encoding = settings.default_encoding
          end
          lines = app.count("\n") + 1
          template = nil
          force_encoding data, encoding
          data.each_line do |line|
            lines += 1
            if line =~ /^@@\s*(.*\S)\s*$/
              template = force_encoding(String.new, encoding)
              templates[$1.to_sym] = [template, file, lines]
            elsif template
              template << line
            end
          end
        end
      end

      # Lookup or register a mime type in Rack's mime registry.
      def mime_type(type, value = nil)
        return type      if type.nil?
        return type.to_s if type.to_s.include?('/')
        type = ".#{type}" unless type.to_s[0] == ?.
        return Rack::Mime.mime_type(type, nil) unless value
        Rack::Mime::MIME_TYPES[type] = value
      end

      # provides all mime types matching type, including deprecated types:
      #   mime_types :html # => ['text/html']
      #   mime_types :js   # => ['application/javascript', 'text/javascript']
      def mime_types(type)
        type = mime_type type
        type =~ /^application\/(xml|javascript)$/ ? [type, "text/#$1"] : [type]
      end

      # Define a before filter; runs before all requests within the same
      # context as route handlers and may access/modify the request and
      # response.
      def before(path = /.*/, **options, &block)
        add_filter(:before, path, **options, &block)
      end

      # Define an after filter; runs after all requests within the same
      # context as route handlers and may access/modify the request and
      # response.
      def after(path = /.*/, **options, &block)
        add_filter(:after, path, **options, &block)
      end

      # add a filter
      def add_filter(type, path = /.*/, **options, &block)
        filters[type] << compile!(type, path, block, **options)
      end

      # Add a route condition. The route is considered non-matching when the
      # block returns false.
      def condition(name = "#{caller.first[/`.*'/]} condition", &block)
        @conditions << generate_method(name, &block)
      end

      def public=(value)
        warn ":public is no longer used to avoid overloading Module#public, use :public_folder or :public_dir instead"
        set(:public_folder, value)
      end

      def public_dir=(value)
        self.public_folder = value
      end

      def public_dir
        public_folder
      end

      # Defining a `GET` handler also automatically defines
      # a `HEAD` handler.
      def get(path, opts = {}, &block)
        conditions = @conditions.dup
        route('GET', path, opts, &block)

        @conditions = conditions
        route('HEAD', path, opts, &block)
      end

      def put(path, opts = {}, &bk)     route 'PUT',     path, opts, &bk end
      def post(path, opts = {}, &bk)    route 'POST',    path, opts, &bk end
      def delete(path, opts = {}, &bk)  route 'DELETE',  path, opts, &bk end
      def head(path, opts = {}, &bk)    route 'HEAD',    path, opts, &bk end
      def options(path, opts = {}, &bk) route 'OPTIONS', path, opts, &bk end
      def patch(path, opts = {}, &bk)   route 'PATCH',   path, opts, &bk end
      def link(path, opts = {}, &bk)    route 'LINK',    path, opts, &bk end
      def unlink(path, opts = {}, &bk)  route 'UNLINK',  path, opts, &bk end

      # Makes the methods defined in the block and in the Modules given
      # in `extensions` available to the handlers and templates
      def helpers(*extensions, &block)
        class_eval(&block)   if block_given?
        prepend(*extensions) if extensions.any?
      end

      # Register an extension. Alternatively take a block from which an
      # extension will be created and registered on the fly.
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
      def configure(*envs)
        yield self if envs.empty? || envs.include?(environment.to_sym)
      end

      # Use the specified Rack middleware
      def use(middleware, *args, &block)
        @prototype = nil
        @middleware << [middleware, args, block]
      end

      # Stop the self-hosted server if running.
      def quit!
        return unless running?
        # Use Thin's hard #stop! if available, otherwise just #stop.
        running_server.respond_to?(:stop!) ? running_server.stop! : running_server.stop
        $stderr.puts "== Sinatra has ended his set (crowd applauds)" unless suppress_messages?
        set :running_server, nil
        set :handler_name, nil
      end

      alias_method :stop!, :quit!

      # Run the Sinatra app as a self-hosted server using
      # Puma, Mongrel, or WEBrick (in that order). If given a block, will call
      # with the constructed handler once we have taken the stage.
      def run!(options = {}, &block)
        return if running?
        set options
        handler         = Rack::Handler.pick(server)
        handler_name    = handler.name.gsub(/.*::/, '')
        server_settings = settings.respond_to?(:server_settings) ? settings.server_settings : {}
        server_settings.merge!(:Port => port, :Host => bind)

        begin
          start_server(handler, server_settings, handler_name, &block)
        rescue Errno::EADDRINUSE
          $stderr.puts "== Someone is already performing on port #{port}!"
          raise
        ensure
          quit!
        end
      end

      alias_method :start!, :run!

      # Check whether the self-hosted server is running or not.
      def running?
        running_server?
      end

      # The prototype instance used to process requests.
      def prototype
        @prototype ||= new
      end

      # Create a new instance without middleware in front of it.
      alias new! new unless method_defined? :new!

      # Create a new instance of the class fronted by its middleware
      # pipeline. The object is guaranteed to respond to #call but may not be
      # an instance of the class new was called on.
      def new(*args, &bk)
        instance = new!(*args, &bk)
        Wrapper.new(build(instance).to_app, instance)
      end

      # Creates a Rack::Builder instance with all the middleware set up and
      # the given +app+ as end point.
      def build(app)
        builder = Rack::Builder.new
        setup_default_middleware builder
        setup_middleware builder
        builder.run app
        builder
      end

      def call(env)
        synchronize { prototype.call(env) }
      end

      # Like Kernel#caller but excluding certain magic entries and without
      # line / method information; the resulting array contains filenames only.
      def caller_files
        cleaned_caller(1).flatten
      end

      # Like caller_files, but containing Arrays rather than strings with the
      # first element being the file, and the second being the line.
      def caller_locations
        cleaned_caller 2
      end

      private

      # Starts the server by running the Rack Handler.
      def start_server(handler, server_settings, handler_name)
        # Ensure we initialize middleware before startup, to match standard Rack
        # behavior, by ensuring an instance exists:
        prototype
        # Run the instance we created:
        handler.run(self, **server_settings) do |server|
          unless suppress_messages?
            $stderr.puts "== Sinatra (v#{Sinatra::VERSION}) has taken the stage on #{port} for #{environment} with backup from #{handler_name}"
          end

          setup_traps
          set :running_server, server
          set :handler_name,   handler_name
          server.threaded = settings.threaded if server.respond_to? :threaded=

          yield server if block_given?
        end
      end

      def suppress_messages?
        handler_name =~ /cgi/i || quiet
      end

      def setup_traps
        if traps?
          at_exit { quit! }

          [:INT, :TERM].each do |signal|
            old_handler = trap(signal) do
              quit!
              old_handler.call if old_handler.respond_to?(:call)
            end
          end

          set :traps, false
        end
      end

      # Dynamically defines a method on settings.
      def define_singleton(name, content = Proc.new)
        singleton_class.class_eval do
          undef_method(name) if method_defined? name
          String === content ? class_eval("def #{name}() #{content}; end") : define_method(name, &content)
        end
      end

      # Condition for matching host name. Parameter might be String or Regexp.
      def host_name(pattern)
        condition { pattern === request.host }
      end

      # Condition for matching user agent. Parameter should be Regexp.
      # Will set params[:agent].
      def user_agent(pattern)
        condition do
          if request.user_agent.to_s =~ pattern
            @params[:agent] = $~[1..-1]
            true
          else
            false
          end
        end
      end
      alias_method :agent, :user_agent

      # Condition for matching mimetypes. Accepts file extensions.
      def provides(*types)
        types.map! { |t| mime_types(t) }
        types.flatten!
        condition do
          if type = response['Content-Type']
            types.include? type or types.include? type[/^[^;]+/]
          elsif type = request.preferred_type(types)
            params = (type.respond_to?(:params) ? type.params : {})
            content_type(type, params)
            true
          else
            false
          end
        end
      end

      def route(verb, path, options = {}, &block)
        enable :empty_path_info if path == "" and empty_path_info.nil?
        signature = compile!(verb, path, block, **options)
        (@routes[verb] ||= []) << signature
        invoke_hook(:route_added, verb, path, block)
        signature
      end

      def invoke_hook(name, *args)
        extensions.each { |e| e.send(name, *args) if e.respond_to?(name) }
      end

      def generate_method(method_name, &block)
        define_method(method_name, &block)
        method = instance_method method_name
        remove_method method_name
        method
      end

      def compile!(verb, path, block, **options)
        # Because of self.options.host
        host_name(options.delete(:host)) if options.key?(:host)
        # Pass Mustermann opts to compile()
        route_mustermann_opts = options.key?(:mustermann_opts) ? options.delete(:mustermann_opts) : {}.freeze

        options.each_pair { |option, args| send(option, *args) }

        pattern                 = compile(path, route_mustermann_opts)
        method_name             = "#{verb} #{path}"
        unbound_method          = generate_method(method_name, &block)
        conditions, @conditions = @conditions, []
        wrapper                 = block.arity != 0 ?
          proc { |a, p| unbound_method.bind(a).call(*p) } :
          proc { |a, p| unbound_method.bind(a).call }

        [ pattern, conditions, wrapper ]
      end

      def compile(path, route_mustermann_opts = {})
        Mustermann.new(path, **mustermann_opts.merge(route_mustermann_opts))
      end

      def setup_default_middleware(builder)
        builder.use ExtendedRack
        builder.use ShowExceptions       if show_exceptions?
        builder.use Rack::MethodOverride if method_override?
        builder.use Rack::Head
        setup_logging    builder
        setup_sessions   builder
        setup_protection builder
      end

      def setup_middleware(builder)
        middleware.each { |c,a,b| builder.use(c, *a, &b) }
      end

      def setup_logging(builder)
        if logging?
          setup_common_logger(builder)
          setup_custom_logger(builder)
        elsif logging == false
          setup_null_logger(builder)
        end
      end

      def setup_null_logger(builder)
        builder.use Rack::NullLogger
      end

      def setup_common_logger(builder)
        builder.use Sinatra::CommonLogger
      end

      def setup_custom_logger(builder)
        if logging.respond_to? :to_int
          builder.use Rack::Logger, logging
        else
          builder.use Rack::Logger
        end
      end

      def setup_protection(builder)
        return unless protection?
        options = Hash === protection ? protection.dup : {}
        options = {
          img_src:  "'self' data:",
          font_src: "'self'"
        }.merge options

        protect_session = options.fetch(:session) { sessions? }
        options[:without_session] = !protect_session

        options[:reaction] ||= :drop_session

        builder.use Rack::Protection, options
      end

      def setup_sessions(builder)
        return unless sessions?
        options = {}
        options[:secret] = session_secret if session_secret?
        options.merge! sessions.to_hash if sessions.respond_to? :to_hash
        builder.use session_store, options
      end

      def inherited(subclass)
        subclass.reset!
        subclass.set :app_file, caller_files.first unless subclass.app_file?
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

      # used for deprecation warnings
      def warn(message)
        super message + "\n\tfrom #{cleaned_caller.first.join(':')}"
      end

      # Like Kernel#caller but excluding certain magic entries
      def cleaned_caller(keep = 3)
        caller(1).
          map!    { |line| line.split(/:(?=\d|in )/, 3)[0,keep] }.
          reject { |file, *_| CALLERS_TO_IGNORE.any? { |pattern| file =~ pattern } }
      end
    end

    # Force data to specified encoding. It defaults to settings.default_encoding
    # which is UTF-8 by default
    def self.force_encoding(data, encoding = default_encoding)
      return if data == settings || data.is_a?(Tempfile)
      if data.respond_to? :force_encoding
        data.force_encoding(encoding).encode!
      elsif data.respond_to? :each_value
        data.each_value { |v| force_encoding(v, encoding) }
      elsif data.respond_to? :each
        data.each { |v| force_encoding(v, encoding) }
      end
      data
    end

    def force_encoding(*args) settings.force_encoding(*args) end

    reset!

    set :environment, (ENV['APP_ENV'] || ENV['RACK_ENV'] || :development).to_sym
    set :raise_errors, Proc.new { test? }
    set :dump_errors, Proc.new { !test? }
    set :show_exceptions, Proc.new { development? }
    set :sessions, false
    set :session_store, Rack::Session::Cookie
    set :logging, false
    set :protection, true
    set :method_override, false
    set :use_code, false
    set :default_encoding, "utf-8"
    set :x_cascade, true
    set :add_charset, %w[javascript xml xhtml+xml].map { |t| "application/#{t}" }
    settings.add_charset << /^text\//
    set :mustermann_opts, {}
    set :default_content_type, 'text/html'

    # explicitly generating a session secret eagerly to play nice with preforking
    begin
      require 'securerandom'
      set :session_secret, SecureRandom.hex(64)
    rescue LoadError, NotImplementedError
      # SecureRandom raises a NotImplementedError if no random device is available
      set :session_secret, "%064x" % Kernel.rand(2**256-1)
    end

    class << self
      alias_method :methodoverride?, :method_override?
      alias_method :methodoverride=, :method_override=
    end

    set :run, false                       # start server via at-exit hook?
    set :running_server, nil
    set :handler_name, nil
    set :traps, true
    set :server, %w[HTTP webrick]
    set :bind, Proc.new { development? ? 'localhost' : '0.0.0.0' }
    set :port, Integer(ENV['PORT'] && !ENV['PORT'].empty? ? ENV['PORT'] : 4567)
    set :quiet, false

    ruby_engine = defined?(RUBY_ENGINE) && RUBY_ENGINE

    if ruby_engine == 'macruby'
      server.unshift 'control_tower'
    else
      server.unshift 'reel'
      server.unshift 'puma'
      server.unshift 'mongrel'  if ruby_engine.nil?
      server.unshift 'thin'     if ruby_engine != 'jruby'
      server.unshift 'trinidad' if ruby_engine == 'jruby'
    end

    set :absolute_redirects, true
    set :prefixed_redirects, false
    set :empty_path_info, nil
    set :strict_paths, true

    set :app_file, nil
    set :root, Proc.new { app_file && File.expand_path(File.dirname(app_file)) }
    set :views, Proc.new { root && File.join(root, 'views') }
    set :reload_templates, Proc.new { development? }
    set :lock, false
    set :threaded, true

    set :public_folder, Proc.new { root && File.join(root, 'public') }
    set :static, Proc.new { public_folder && File.exist?(public_folder) }
    set :static_cache_control, false

    error ::Exception do
      response.status = 500
      content_type 'text/html'
      '<h1>Internal Server Error</h1>'
    end

    configure :development do
      get '/__sinatra__/:image.png' do
        filename = __dir__ + "/images/#{params[:image].to_i}.png"
        content_type :png
        send_file filename
      end

      error NotFound do
        content_type 'text/html'

        if self.class == Sinatra::Application
          code = <<-RUBY.gsub(/^ {12}/, '')
            #{request.request_method.downcase} '#{request.path_info}' do
              "Hello World"
            end
          RUBY
        else
          code = <<-RUBY.gsub(/^ {12}/, '')
            class #{self.class}
              #{request.request_method.downcase} '#{request.path_info}' do
                "Hello World"
              end
            end
          RUBY

          file = settings.app_file.to_s.sub(settings.root.to_s, '').sub(/^\//, '')
          code = "# in #{file}\n#{code}" unless file.empty?
        end

        (<<-HTML).gsub(/^ {10}/, '')
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
            <h2>Sinatra doesn’t know this ditty.</h2>
            <img src='#{uri "/__sinatra__/404.png"}'>
            <div id="c">
              Try this:
              <pre>#{Rack::Utils.escape_html(code)}</pre>
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
  # top-level. Subclassing Sinatra::Base is highly recommended for
  # modular applications.
  class Application < Base
    set :logging, Proc.new { !test? }
    set :method_override, true
    set :run, Proc.new { !test? }
    set :app_file, nil

    def self.register(*extensions, &block) #:nodoc:
      added_methods = extensions.flat_map(&:public_instance_methods)
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
        define_method(method_name) do |*args, &block|
          return super(*args, &block) if respond_to? method_name
          Delegator.target.send(method_name, *args, &block)
        end
        private method_name
      end
    end

    delegate :get, :patch, :put, :post, :delete, :head, :options, :link, :unlink,
             :template, :layout, :before, :after, :error, :not_found, :configure,
             :set, :mime_type, :enable, :disable, :use, :development?, :test?,
             :production?, :helpers, :settings, :register

    class << self
      attr_accessor :target
    end

    self.target = Application
  end

  class Wrapper
    def initialize(stack, instance)
      @stack, @instance = stack, instance
    end

    def settings
      @instance.settings
    end

    def helpers
      @instance
    end

    def call(env)
      @stack.call(env)
    end

    def inspect
      "#<#{@instance.class} app_file=#{settings.app_file.inspect}>"
    end
  end

  # Create a new Sinatra application; the block is evaluated in the class scope.
  def self.new(base = Base, &block)
    base = Class.new(base)
    base.class_eval(&block) if block_given?
    base
  end

  # Extend the top-level DSL with the modules provided.
  def self.register(*extensions, &block)
    Delegator.target.register(*extensions, &block)
  end

  # Include the helper modules provided in Sinatra's request context.
  def self.helpers(*extensions, &block)
    Delegator.target.helpers(*extensions, &block)
  end

  # Use the middleware for classic applications.
  def self.use(*args, &block)
    Delegator.target.use(*args, &block)
  end
end
