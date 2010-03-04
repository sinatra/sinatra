module Tilt
  VERSION = '0.7'

  @template_mappings = {}

  # Hash of template path pattern => template implementation class mappings.
  def self.mappings
    @template_mappings
  end

  # Register a template implementation by file extension.
  def self.register(ext, template_class)
    ext = ext.to_s.sub(/^\./, '')
    mappings[ext.downcase] = template_class
  end

  # Create a new template for the given file using the file's extension
  # to determine the the template mapping.
  def self.new(file, line=nil, options={}, &block)
    if template_class = self[file]
      template_class.new(file, line, options, &block)
    else
      fail "No template engine registered for #{File.basename(file)}"
    end
  end

  # Lookup a template class for the given filename or file
  # extension. Return nil when no implementation is found.
  def self.[](file)
    if @template_mappings.key?(pattern = file.to_s.downcase)
      @template_mappings[pattern]
    elsif @template_mappings.key?(pattern = File.basename(pattern))
      @template_mappings[pattern]
    else
      while !pattern.empty?
        if @template_mappings.key?(pattern)
          return @template_mappings[pattern]
        else
          pattern = pattern.sub(/^[^.]*\.?/, '')
        end
      end
      nil
    end
  end

  # Mixin allowing template compilation on scope objects.
  #
  # Including this module in scope objects passed to Template#render
  # causes template source to be compiled to methods the first time they're
  # used. This can yield significant (5x-10x) performance increases for
  # templates that support it (ERB, Erubis, Builder).
  #
  # It's also possible (though not recommended) to include this module in
  # Object to enable template compilation globally. The downside is that
  # the template methods will polute the global namespace and could lead to
  # unexpected behavior.
  module CompileSite
    def __tilt__
    end
  end

  # Base class for template implementations. Subclasses must implement
  # the #prepare method and one of the #evaluate or #template_source
  # methods.
  class Template
    # Template source; loaded from a file or given directly.
    attr_reader :data

    # The name of the file where the template data was loaded from.
    attr_reader :file

    # The line number in #file where template data was loaded from.
    attr_reader :line

    # A Hash of template engine specific options. This is passed directly
    # to the underlying engine and is not used by the generic template
    # interface.
    attr_reader :options

    # Used to determine if this class's initialize_engine method has
    # been called yet.
    @engine_initialized = false
    class << self
      attr_accessor :engine_initialized
      alias engine_initialized? engine_initialized
    end

    # Create a new template with the file, line, and options specified. By
    # default, template data is read from the file. When a block is given,
    # it should read template data and return as a String. When file is nil,
    # a block is required.
    #
    # All arguments are optional.
    def initialize(file=nil, line=1, options={}, &block)
      @file, @line, @options = nil, 1, {}

      [options, line, file].compact.each do |arg|
        case
        when arg.respond_to?(:to_str)  ; @file = arg.to_str
        when arg.respond_to?(:to_int)  ; @line = arg.to_int
        when arg.respond_to?(:to_hash) ; @options = arg.to_hash
        else raise TypeError
        end
      end

      raise ArgumentError, "file or block required" if (@file || block).nil?

      # call the initialize_engine method if this is the very first time
      # an instance of this class has been created.
      if !self.class.engine_initialized?
        initialize_engine
        self.class.engine_initialized = true
      end

      # used to generate unique method names for template compilation
      stamp = (Time.now.to_f * 10000).to_i
      @_prefix = "__tilt_O#{object_id.to_s(16)}T#{stamp.to_s(16)}"

      # load template data and prepare
      @reader = block || lambda { |t| File.read(@file) }
      @data = @reader.call(self)
      prepare
    end

    # Render the template in the given scope with the locals specified. If a
    # block is given, it is typically available within the template via
    # +yield+.
    def render(scope=Object.new, locals={}, &block)
      evaluate scope, locals || {}, &block
    end

    # The basename of the template file.
    def basename(suffix='')
      File.basename(file, suffix) if file
    end

    # The template file's basename with all extensions chomped off.
    def name
      basename.split('.', 2).first if basename
    end

    # The filename used in backtraces to describe the template.
    def eval_file
      file || '(__TEMPLATE__)'
    end

  protected
    # Called once and only once for each template subclass the first time
    # the template class is initialized. This should be used to require the
    # underlying template library and perform any initial setup.
    def initialize_engine
    end

    # Do whatever preparation is necessary to setup the underlying template
    # engine. Called immediately after template data is loaded. Instance
    # variables set in this method are available when #evaluate is called.
    #
    # Subclasses must provide an implementation of this method.
    def prepare
      if respond_to?(:compile!)
        # backward compat with tilt < 0.6; just in case
        warn 'Tilt::Template#compile! is deprecated; implement #prepare instead.'
        compile!
      else
        raise NotImplementedError
      end
    end

    # Process the template and return the result. When the scope mixes in
    # the Tilt::CompileSite module, the template is compiled to a method and
    # reused given identical locals keys. When the scope object
    # does not mix in the CompileSite module, the template source is
    # evaluated with instance_eval. In any case, template executation
    # is guaranteed to be performed in the scope object with the locals
    # specified and with support for yielding to the block.
    def evaluate(scope, locals, &block)
      if scope.respond_to?(:__tilt__)
        method_name = compiled_method_name(locals.keys.hash)
        if scope.respond_to?(method_name)
          # fast path
          scope.send method_name, locals, &block
        else
          # compile first and then run
          compile_template_method(method_name, locals)
          scope.send method_name, locals, &block
        end
      else
        source, offset = local_assignment_code(locals)
        source = [source, template_source].join("\n")
        scope.instance_eval source, eval_file, line - offset
      end
    end

    # Return a string containing the (Ruby) source code for the template. The
    # default Template#evaluate implementation requires this method be
    # defined and guarantees correct file/line handling, custom scopes, and
    # support for template compilation when the scope object allows it.
    def template_source
      raise NotImplementedError
    end

  private
    def local_assignment_code(locals)
      return ['', 1] if locals.empty?
      source = locals.collect { |k,v| "#{k} = locals[:#{k}]" }
      [source.join("\n"), source.length]
    end

    def compiled_method_name(locals_hash)
      "#{@_prefix}L#{locals_hash.to_s(16).sub('-', 'n')}"
    end

    def compile_template_method(method_name, locals)
      source, offset = local_assignment_code(locals)
      source = [source, template_source].join("\n")
      offset += 1

      # add the new method
      CompileSite.module_eval <<-RUBY, eval_file, line - offset
        def #{method_name}(locals)
          #{source}
        end
      RUBY

      # setup a finalizer to remove the newly added method
      ObjectSpace.define_finalizer self,
        Template.compiled_template_method_remover(CompileSite, method_name)
    end

    def self.compiled_template_method_remover(site, method_name)
      proc { |oid| garbage_collect_compiled_template_method(site, method_name) }
    end

    def self.garbage_collect_compiled_template_method(site, method_name)
      site.module_eval do
        begin
          remove_method(method_name)
        rescue NameError
          # method was already removed (ruby >= 1.9)
        end
      end
    end

    def require_template_library(name)
      if Thread.list.size > 1
        warn "WARN: tilt autoloading '#{name}' in a non thread-safe way; " +
             "explicit require '#{name}' suggested."
      end
      require name
    end
  end

  # Extremely simple template cache implementation. Calling applications
  # create a Tilt::Cache instance and use #fetch with any set of hashable
  # arguments (such as those to Tilt.new):
  #   cache = Tilt::Cache.new
  #   cache.fetch(path, line, options) { Tilt.new(path, line, options) }
  #
  # Subsequent invocations return the already loaded template object.
  class Cache
    def initialize
      @cache = {}
    end

    def fetch(*key)
      @cache[key] ||= yield
    end

    def clear
      @cache = {}
    end
  end


  # Template Implementations ================================================


  # The template source is evaluated as a Ruby string. The #{} interpolation
  # syntax can be used to generated dynamic output.
  class StringTemplate < Template
    def prepare
      @code = "%Q{#{data}}"
    end

    def template_source
      @code
    end
  end
  register 'str', StringTemplate


  # ERB template implementation. See:
  # http://www.ruby-doc.org/stdlib/libdoc/erb/rdoc/classes/ERB.html
  class ERBTemplate < Template
    def initialize_engine
      require_template_library 'erb' unless defined? ::ERB
    end

    def prepare
      @outvar = (options[:outvar] || '_erbout').to_s
      @engine = ::ERB.new(data, options[:safe], options[:trim], @outvar)
    end

    def template_source
      @engine.src
    end

    def evaluate(scope, locals, &block)
      preserve_outvar_value(scope) { super }
    end

  private
    # Retains the previous value of outvar when configured to use
    # an instance variable. This allows multiple templates to be rendered
    # within the context of an object without overwriting the outvar.
    def preserve_outvar_value(scope)
      if @outvar[0] == ?@
        previous = scope.instance_variable_get(@outvar)
        output = yield
        scope.instance_variable_set(@outvar, previous)
        output
      else
        yield
      end
    end

    # ERB generates a line to specify the character coding of the generated
    # source in 1.9. Account for this in the line offset.
    if RUBY_VERSION >= '1.9.0'
      def local_assignment_code(locals)
        source, offset = super
        [source, offset + 1]
      end
    end
  end
  %w[erb rhtml].each { |ext| register ext, ERBTemplate }


  # Erubis template implementation. See:
  # http://www.kuwata-lab.com/erubis/
  class ErubisTemplate < ERBTemplate
    def initialize_engine
      require_template_library 'erubis' unless defined? ::Erubis
    end

    def prepare
      @options.merge!(:preamble => false, :postamble => false)
      @outvar = (options.delete(:outvar) || '_erbout').to_s
      @engine = ::Erubis::Eruby.new(data, options)
    end

    def template_source
      ["#{@outvar} = _buf = ''", @engine.src, "_buf.to_s"].join(";")
    end

  private
    # Erubis doesn't have ERB's line-off-by-one under 1.9 problem. Override
    # and adjust back.
    if RUBY_VERSION >= '1.9.0'
      def local_assignment_code(locals)
        source, offset = super
        [source, offset - 1]
      end
    end
  end
  register 'erubis', ErubisTemplate


  # Haml template implementation. See:
  # http://haml.hamptoncatlin.com/
  class HamlTemplate < Template
    def initialize_engine
      require_template_library 'haml' unless defined? ::Haml::Engine
    end

    def prepare
      @engine = ::Haml::Engine.new(data, haml_options)
    end

    # Precompiled Haml source. Taken from the precompiled_with_ambles
    # method in Haml::Precompiler:
    # http://github.com/nex3/haml/blob/master/lib/haml/precompiler.rb#L111-126
    def template_source
      @engine.instance_eval do
        <<-RUBY
          _haml_locals = locals
          begin
            extend Haml::Helpers
            _hamlout = @haml_buffer = Haml::Buffer.new(@haml_buffer, #{options_for_buffer.inspect})
            _erbout = _hamlout.buffer
            __in_erb_template = true
            #{precompiled}
            #{precompiled_method_return_value}
          ensure
            @haml_buffer = @haml_buffer.upper
          end
        RUBY
      end
    end

  private
    def local_assignment_code(locals)
      source, offset = super
      [source, offset + 6]
    end

    def haml_options
      options.merge(:filename => eval_file, :line => line)
    end
  end
  register 'haml', HamlTemplate


  # Sass template implementation. See:
  # http://haml.hamptoncatlin.com/
  #
  # Sass templates do not support object scopes, locals, or yield.
  class SassTemplate < Template
    def initialize_engine
      require_template_library 'sass' unless defined? ::Sass::Engine
    end

    def prepare
      @engine = ::Sass::Engine.new(data, sass_options)
    end

    def evaluate(scope, locals, &block)
      @output ||= @engine.render
    end

  private
    def sass_options
      options.merge(:filename => eval_file, :line => line)
    end
  end
  register 'sass', SassTemplate


  # Lessscss template implementation. See:
  # http://lesscss.org/
  #
  # Less templates do not support object scopes, locals, or yield.
  class LessTemplate < Template
    def initialize_engine
      require_template_library 'less' unless defined? ::Less::Engine
    end

    def prepare
      @engine = ::Less::Engine.new(data)
    end

    def evaluate(scope, locals, &block)
      @engine.to_css
    end
  end
  register 'less', LessTemplate


  # Builder template implementation. See:
  # http://builder.rubyforge.org/
  class BuilderTemplate < Template
    def initialize_engine
      require_template_library 'builder' unless defined?(::Builder)
    end

    def prepare
    end

    def evaluate(scope, locals, &block)
      xml = ::Builder::XmlMarkup.new(:indent => 2)
      if data.respond_to?(:to_str)
        locals[:xml] = xml
        super(scope, locals, &block)
      elsif data.kind_of?(Proc)
        data.call(xml)
      end
      xml.target!
    end

    def template_source
      data.to_str
    end
  end
  register 'builder', BuilderTemplate


  # Liquid template implementation. See:
  # http://liquid.rubyforge.org/
  #
  # Liquid is designed to be a *safe* template system and threfore
  # does not provide direct access to execuatable scopes. In order to
  # support a +scope+, the +scope+ must be able to represent itself
  # as a hash by responding to #to_h. If the +scope+ does not respond
  # to #to_h it will be ignored.
  #
  # LiquidTemplate does not support yield blocks.
  #
  # It's suggested that your program require 'liquid' at load
  # time when using this template engine.
  class LiquidTemplate < Template
    def initialize_engine
      require_template_library 'liquid' unless defined? ::Liquid::Template
    end

    def prepare
      @engine = ::Liquid::Template.parse(data)
    end

    def evaluate(scope, locals, &block)
      locals = locals.inject({}){ |h,(k,v)| h[k.to_s] = v ; h }
      if scope.respond_to?(:to_h)
        scope  = scope.to_h.inject({}){ |h,(k,v)| h[k.to_s] = v ; h }
        locals = scope.merge(locals)
      end
      locals['yield'] = block.nil? ? '' : yield
      locals['content'] = locals['yield']
      @engine.render(locals)
    end
  end
  register 'liquid', LiquidTemplate


  # Discount Markdown implementation. See:
  # http://github.com/rtomayko/rdiscount
  #
  # RDiscount is a simple text filter. It does not support +scope+ or
  # +locals+. The +:smart+ and +:filter_html+ options may be set true
  # to enable those flags on the underlying RDiscount object.
  class RDiscountTemplate < Template
    def flags
      [:smart, :filter_html].select { |flag| options[flag] }
    end

    def initialize_engine
      require_template_library 'rdiscount' unless defined? ::RDiscount
    end

    def prepare
      @engine = RDiscount.new(data, *flags)
    end

    def evaluate(scope, locals, &block)
      @engine.to_html
    end
  end
  register 'markdown', RDiscountTemplate
  register 'mkd', RDiscountTemplate
  register 'md', RDiscountTemplate


  # RedCloth implementation. See:
  # http://redcloth.org/
  class RedClothTemplate < Template
    def initialize_engine
      require_template_library 'redcloth' unless defined? ::RedCloth
    end

    def prepare
      @engine = RedCloth.new(data)
    end

    def evaluate(scope, locals, &block)
      @engine.to_html
    end
  end
  register 'textile', RedClothTemplate


  # Mustache is written and maintained by Chris Wanstrath. See:
  # http://github.com/defunkt/mustache
  #
  # When a scope argument is provided to MustacheTemplate#render, the
  # instance variables are copied from the scope object to the Mustache
  # view.
  class MustacheTemplate < Template
    attr_reader :engine

    def initialize_engine
      require_template_library 'mustache' unless defined? ::Mustache
    end

    def prepare
      Mustache.view_namespace = options[:namespace]
      Mustache.view_path = options[:view_path] || options[:mustaches]
      @engine = options[:view] || Mustache.view_class(name)
      options.each do |key, value|
        next if %w[view view_path namespace mustaches].include?(key.to_s)
        @engine.send("#{key}=", value) if @engine.respond_to? "#{key}="
      end
    end

    def evaluate(scope=nil, locals={}, &block)
      instance = @engine.new

      # copy instance variables from scope to the view
      scope.instance_variables.each do |name|
        instance.instance_variable_set(name, scope.instance_variable_get(name))
      end

      # locals get added to the view's context
      locals.each do |local, value|
        instance[local] = value
      end

      # if we're passed a block it's a subview. Sticking it in yield
      # lets us use {{yield}} in layout.html to render the actual page.
      instance[:yield] = block.call if block

      instance.template = data unless instance.compiled?

      instance.to_html
    end
  end
  register 'mustache', MustacheTemplate


  # RDoc template. See:
  # http://rdoc.rubyforge.org/
  #
  # It's suggested that your program require 'rdoc/markup' and
  # 'rdoc/markup/to_html' at load time when using this template
  # engine.
  class RDocTemplate < Template
    def initialize_engine
      unless defined?(::RDoc::Markup)
        require_template_library 'rdoc/markup'
        require_template_library 'rdoc/markup/to_html'
      end
    end

    def prepare
      markup = RDoc::Markup::ToHtml.new
      @engine = markup.convert(data)
    end

    def evaluate(scope, locals, &block)
      @engine.to_s
    end
  end
  register 'rdoc', RDocTemplate


  # CoffeeScript info:
  # http://jashkenas.github.com/coffee-script/
  class CoffeeTemplate < Template
    def initialize_engine
      require_template_library 'coffee-script' unless defined? ::CoffeeScript
    end

    def prepare
      @engine = ::CoffeeScript::compile(data, options)
    end

    def evaluate(scope, locals, &block)
      @engine
    end
  end
  register 'coffee', CoffeeTemplate
end
