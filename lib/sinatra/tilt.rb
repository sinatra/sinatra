require 'digest/md5'

module Tilt
  VERSION = '1.0.1'

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

  # Returns true when a template exists on an exact match of the provided file extension
  def self.registered?(ext)
    mappings.key?(ext.downcase)
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
    pattern = file.to_s.downcase
    unless registered?(pattern)
      pattern = File.basename(pattern)
      pattern.sub!(/^[^.]*\.?/, '') until (pattern.empty? || registered?(pattern))
    end
    @template_mappings[pattern]
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
  # the #prepare method and one of the #evaluate or #precompiled_template
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
        when arg.respond_to?(:to_hash) ; @options = arg.to_hash.dup
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
      @stamp = (Time.now.to_f * 10000).to_i
      @compiled_method_names = {}

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

    # Like Kernel::require but issues a warning urging a manual require when
    # running under a threaded environment.
    def require_template_library(name)
      if Thread.list.size > 1
        warn "WARN: tilt autoloading '#{name}' in a non thread-safe way; " +
             "explicit require '#{name}' suggested."
      end
      require name
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
        method_name = compiled_method_name(locals.keys)
        if scope.respond_to?(method_name)
          scope.send(method_name, locals, &block)
        else
          compile_template_method(method_name, locals)
          scope.send(method_name, locals, &block)
        end
      else
        evaluate_source(scope, locals, &block)
      end
    end

    # Generates all template source by combining the preamble, template, and
    # postamble and returns a two-tuple of the form: [source, offset], where
    # source is the string containing (Ruby) source code for the template and
    # offset is the integer line offset where line reporting should begin.
    #
    # Template subclasses may override this method when they need complete
    # control over source generation or want to adjust the default line
    # offset. In most cases, overriding the #precompiled_template method is
    # easier and more appropriate.
    def precompiled(locals)
      preamble = precompiled_preamble(locals)
      parts = [
        preamble,
        precompiled_template(locals),
        precompiled_postamble(locals)
      ]
      [parts.join("\n"), preamble.count("\n") + 1]
    end

    # A string containing the (Ruby) source code for the template. The
    # default Template#evaluate implementation requires either this method
    # or the #precompiled method be overridden. When defined, the base
    # Template guarantees correct file/line handling, locals support, custom
    # scopes, and support for template compilation when the scope object
    # allows it.
    def precompiled_template(locals)
      raise NotImplementedError
    end

    # Generates preamble code for initializing template state, and performing
    # locals assignment. The default implementation performs locals
    # assignment only. Lines included in the preamble are subtracted from the
    # source line offset, so adding code to the preamble does not effect line
    # reporting in Kernel::caller and backtraces.
    def precompiled_preamble(locals)
      locals.map { |k,v| "#{k} = locals[:#{k}]" }.join("\n")
    end

    # Generates postamble code for the precompiled template source. The
    # string returned from this method is appended to the precompiled
    # template source.
    def precompiled_postamble(locals)
      ''
    end

    # The unique compiled method name for the locals keys provided.
    def compiled_method_name(locals_keys)
      @compiled_method_names[locals_keys] ||=
        generate_compiled_method_name(locals_keys)
    end

  private
    # Evaluate the template source in the context of the scope object.
    def evaluate_source(scope, locals, &block)
      source, offset = precompiled(locals)
      scope.instance_eval(source, eval_file, line - offset)
    end

    # JRuby doesn't allow Object#instance_eval to yield to the block it's
    # closed over. This is by design and (ostensibly) something that will
    # change in MRI, though no current MRI version tested (1.8.6 - 1.9.2)
    # exhibits the behavior. More info here:
    #
    # http://jira.codehaus.org/browse/JRUBY-2599
    #
    # Additionally, JRuby's eval line reporting is off by one compared to
    # all MRI versions tested.
    #
    # We redefine evaluate_source to work around both issues.
    if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'
      undef evaluate_source
      def evaluate_source(scope, locals, &block)
        source, offset = precompiled(locals)
        file, lineno = eval_file, (line - offset) - 1
        scope.instance_eval { Kernel::eval(source, binding, file, lineno) }
      end
    end

    def generate_compiled_method_name(locals_keys)
      parts = [object_id, @stamp] + locals_keys.map { |k| k.to_s }.sort
      digest = Digest::MD5.hexdigest(parts.join(':'))
      "__tilt_#{digest}"
    end

    def compile_template_method(method_name, locals)
      source, offset = precompiled(locals)
      offset += 5
      CompileSite.class_eval <<-RUBY, eval_file, line - offset
        def #{method_name}(locals)
          Thread.current[:tilt_vars] = [self, locals]
          class << self
            this, locals = Thread.current[:tilt_vars]
            this.instance_eval do
              #{source}
            end
          end
        end
      RUBY
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

    def precompiled_template(locals)
      @code
    end
  end
  register 'str', StringTemplate


  # ERB template implementation. See:
  # http://www.ruby-doc.org/stdlib/libdoc/erb/rdoc/classes/ERB.html
  class ERBTemplate < Template
    @@default_output_variable = '_erbout'

    def self.default_output_variable
      @@default_output_variable
    end

    def self.default_output_variable=(name)
      @@default_output_variable = name
    end

    def initialize_engine
      return if defined? ::ERB
      require_template_library 'erb'
    end

    def prepare
      @outvar = options[:outvar] || self.class.default_output_variable
      @engine = ::ERB.new(data, options[:safe], options[:trim], @outvar)
    end

    def precompiled_template(locals)
      source = @engine.src
      source
    end

    def precompiled_preamble(locals)
      <<-RUBY
        begin
          __original_outvar = #{@outvar} if defined?(#{@outvar})
          #{super}
      RUBY
    end

    def precompiled_postamble(locals)
      <<-RUBY
          #{super}
        ensure
          #{@outvar} = __original_outvar
        end
      RUBY
    end

    # ERB generates a line to specify the character coding of the generated
    # source in 1.9. Account for this in the line offset.
    if RUBY_VERSION >= '1.9.0'
      def precompiled(locals)
        source, offset = super
        [source, offset + 1]
      end
    end
  end

  %w[erb rhtml].each { |ext| register ext, ERBTemplate }


  # Erubis template implementation. See:
  # http://www.kuwata-lab.com/erubis/
  #
  # ErubisTemplate supports the following additional options, which are not
  # passed down to the Erubis engine:
  #
  #   :engine_class   allows you to specify a custom engine class to use
  #                   instead of the default (which is ::Erubis::Eruby).
  #
  #   :escape_html    when true, ::Erubis::EscapedEruby will be used as
  #                   the engine class instead of the default. All content
  #                   within <%= %> blocks will be automatically html escaped.
  class ErubisTemplate < ERBTemplate
    def initialize_engine
      return if defined? ::Erubis
      require_template_library 'erubis'
    end

    def prepare
      @options.merge!(:preamble => false, :postamble => false)
      @outvar = options.delete(:outvar) || self.class.default_output_variable
      engine_class = options.delete(:engine_class)
      engine_class = ::Erubis::EscapedEruby if options.delete(:escape_html)
      @engine = (engine_class || ::Erubis::Eruby).new(data, options)
    end

    def precompiled_preamble(locals)
      [super, "#{@outvar} = _buf = ''"].join("\n")
    end

    def precompiled_postamble(locals)
      ["_buf", super].join("\n")
    end

    # Erubis doesn't have ERB's line-off-by-one under 1.9 problem.
    # Override and adjust back.
    if RUBY_VERSION >= '1.9.0'
      def precompiled(locals)
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
      return if defined? ::Haml::Engine
      require_template_library 'haml'
    end

    def prepare
      options = @options.merge(:filename => eval_file, :line => line)
      @engine = ::Haml::Engine.new(data, options)
    end

    def evaluate(scope, locals, &block)
      if @engine.respond_to?(:precompiled_method_return_value, true)
        super
      else
        @engine.render(scope, locals, &block)
      end
    end

    # Precompiled Haml source. Taken from the precompiled_with_ambles
    # method in Haml::Precompiler:
    # http://github.com/nex3/haml/blob/master/lib/haml/precompiler.rb#L111-126
    def precompiled_template(locals)
      @engine.precompiled
    end

    def precompiled_preamble(locals)
      local_assigns = super
      @engine.instance_eval do
        <<-RUBY
          begin
            extend Haml::Helpers
            _hamlout = @haml_buffer = Haml::Buffer.new(@haml_buffer, #{options_for_buffer.inspect})
            _erbout = _hamlout.buffer
            __in_erb_template = true
            _haml_locals = locals
            #{local_assigns}
        RUBY
      end
    end

    def precompiled_postamble(locals)
      @engine.instance_eval do
        <<-RUBY
            #{precompiled_method_return_value}
          ensure
            @haml_buffer = @haml_buffer.upper
          end
        RUBY
      end
    end
  end
  register 'haml', HamlTemplate


  # Sass template implementation. See:
  # http://haml.hamptoncatlin.com/
  #
  # Sass templates do not support object scopes, locals, or yield.
  class SassTemplate < Template
    def initialize_engine
      return if defined? ::Sass::Engine
      require_template_library 'sass'
    end

    def prepare
      @engine = ::Sass::Engine.new(data, sass_options)
    end

    def evaluate(scope, locals, &block)
      @output ||= @engine.render
    end

  private
    def sass_options
      options.merge(:filename => eval_file, :line => line, :syntax => :sass)
    end
  end
  register 'sass', SassTemplate

  # Sass's new .scss type template implementation.
  class ScssTemplate < SassTemplate
  private
    def sass_options
      options.merge(:filename => eval_file, :line => line, :syntax => :scss)
    end
  end
  register 'scss', ScssTemplate

  # Lessscss template implementation. See:
  # http://lesscss.org/
  #
  # Less templates do not support object scopes, locals, or yield.
  class LessTemplate < Template
    def initialize_engine
      return if defined? ::Less::Engine
      require_template_library 'less'
    end

    def prepare
      @engine = ::Less::Engine.new(data)
    end

    def evaluate(scope, locals, &block)
      @engine.to_css
    end
  end
  register 'less', LessTemplate


  # Nokogiri template implementation. See:
  # http://nokogiri.org/
  class NokogiriTemplate < Template
    def initialize_engine
      return if defined?(::Nokogiri)
      require_template_library 'nokogiri'
    end

    def prepare; end

    def evaluate(scope, locals, &block)
      xml = ::Nokogiri::XML::Builder.new
      if data.respond_to?(:to_str)
        locals[:xml] = xml
        super(scope, locals, &block)
      elsif data.kind_of?(Proc)
        data.call(xml)
      end
      xml.to_xml
    end

    def precompiled_template(locals)
      data.to_str
    end
  end
  register 'nokogiri', NokogiriTemplate

  # Builder template implementation. See:
  # http://builder.rubyforge.org/
  class BuilderTemplate < Template
    def initialize_engine
      return if defined?(::Builder)
      require_template_library 'builder'
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

    def precompiled_template(locals)
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
      return if defined? ::Liquid::Template
      require_template_library 'liquid'
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
      return if defined? ::RDiscount
      require_template_library 'rdiscount'
    end

    def prepare
      @engine = RDiscount.new(data, *flags)
      @output = nil
    end

    def evaluate(scope, locals, &block)
      @output ||= @engine.to_html
    end
  end
  register 'markdown', RDiscountTemplate
  register 'mkd', RDiscountTemplate
  register 'md', RDiscountTemplate


  # RedCloth implementation. See:
  # http://redcloth.org/
  class RedClothTemplate < Template
    def initialize_engine
      return if defined? ::RedCloth
      require_template_library 'redcloth'
    end

    def prepare
      @engine = RedCloth.new(data)
      @output = nil
    end

    def evaluate(scope, locals, &block)
      @output ||= @engine.to_html
    end
  end
  register 'textile', RedClothTemplate


  # RDoc template. See:
  # http://rdoc.rubyforge.org/
  #
  # It's suggested that your program require 'rdoc/markup' and
  # 'rdoc/markup/to_html' at load time when using this template
  # engine.
  class RDocTemplate < Template
    def initialize_engine
      return if defined?(::RDoc::Markup)
      require_template_library 'rdoc/markup'
      require_template_library 'rdoc/markup/to_html'
    end

    def prepare
      markup = RDoc::Markup::ToHtml.new
      @engine = markup.convert(data)
      @output = nil
    end

    def evaluate(scope, locals, &block)
      @output ||= @engine.to_s
    end
  end
  register 'rdoc', RDocTemplate


  # Radius Template
  # http://github.com/jlong/radius/
  class RadiusTemplate < Template
    def initialize_engine
      return if defined? ::Radius
      require_template_library 'radius'
    end

    def prepare
    end

    def evaluate(scope, locals, &block)
      context = Class.new(Radius::Context).new
      context.define_tag("yield") do
        block.call
      end
      locals.each do |tag, value|
        context.define_tag(tag) do
          value
        end
      end
      (class << context; self; end).class_eval do
        define_method :tag_missing do |tag, attr|
          scope.__send__(tag)  # any way to support attr as args?
        end
      end
      options = {:tag_prefix => 'r'}.merge(@options)
      parser = Radius::Parser.new(context, options)
      parser.parse(data)
    end
  end
  register 'radius', RadiusTemplate
end
