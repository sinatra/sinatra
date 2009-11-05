module Tilt
  VERSION = '0.3'

  @template_mappings = {}

  # Hash of template path pattern => template implementation
  # class mappings.
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

  # Lookup a template class given for the given filename or file
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


  # Base class for template implementations. Subclasses must implement
  # the #compile! method and one of the #evaluate or #template_source
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

    # Create a new template with the file, line, and options specified. By
    # default, template data is read from the file specified. When a block
    # is given, it should read template data and return as a String. When
    # file is nil, a block is required.
    def initialize(file=nil, line=1, options={}, &block)
      raise ArgumentError, "file or block required" if file.nil? && block.nil?
      options, line = line, 1 if line.is_a?(Hash)
      @file = file
      @line = line || 1
      @options = options || {}
      @reader = block || lambda { |t| File.read(file) }
    end

    # Load template source and compile the template. The template is
    # loaded and compiled the first time this method is called; subsequent
    # calls are no-ops.
    def compile
      if @data.nil?
        @data = @reader.call(self)
        compile!
      end
    end

    # Render the template in the given scope with the locals specified. If a
    # block is given, it is typically available within the template via
    # +yield+.
    def render(scope=Object.new, locals={}, &block)
      compile
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
    # Do whatever preparation is necessary to "compile" the template.
    # Called immediately after template #data is loaded. Instance variables
    # set in this method are available when #evaluate is called.
    #
    # Subclasses must provide an implementation of this method.
    def compile!
      raise NotImplementedError
    end

    # Process the template and return the result. Subclasses should override
    # this method unless they implement the #template_source.
    def evaluate(scope, locals, &block)
      source, offset = local_assignment_code(locals)
      source = [source, template_source].join("\n")
      scope.instance_eval source, eval_file, line - offset
    end

    # Return a string containing the (Ruby) source code for the template. The
    # default Template#evaluate implementation requires this method be
    # defined.
    def template_source
      raise NotImplementedError
    end

  private
    def local_assignment_code(locals)
      return ['', 1] if locals.empty?
      source = locals.collect { |k,v| "#{k} = locals[:#{k}]" }
      [source.join("\n"), source.length]
    end

    def require_template_library(name)
      if Thread.list.size > 1
        warn "WARN: tilt autoloading '#{name}' in a non thread-safe way; " +
             "explicit require '#{name}' suggested."
      end
      require name
    end
  end

  # Extremely simple template cache implementation.
  class Cache
    def initialize
      @cache = {}
    end

    def fetch(*key)
      key = key.map { |part| part.to_s }.join(":")
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
    def compile!
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
    def compile!
      require_template_library 'erb' unless defined?(::ERB)
      @engine = ::ERB.new(data, options[:safe], options[:trim], '@_out_buf')
    end

    def template_source
      @engine.src
    end

    def evaluate(scope, locals, &block)
      source, offset = local_assignment_code(locals)
      source = [source, template_source].join("\n")

      original_out_buf =
        scope.instance_variables.any? { |var| var.to_sym == :@_out_buf } &&
        scope.instance_variable_get(:@_out_buf)

      scope.instance_eval source, eval_file, line - offset

      output = scope.instance_variable_get(:@_out_buf)
      scope.instance_variable_set(:@_out_buf, original_out_buf)

      output
    end

  private

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
    def compile!
      require_template_library 'erubis' unless defined?(::Erubis)
      Erubis::Eruby.class_eval(%Q{def add_preamble(src) src << "@_out_buf = _buf = '';" end})
      @engine = ::Erubis::Eruby.new(data, options)
    end
  end
  register 'erubis', ErubisTemplate


  # Haml template implementation. See:
  # http://haml.hamptoncatlin.com/
  class HamlTemplate < Template
    def compile!
      require_template_library 'haml' unless defined?(::Haml::Engine)
      @engine = ::Haml::Engine.new(data, haml_options)
    end

    def evaluate(scope, locals, &block)
      @engine.render(scope, locals, &block)
    end

  private
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
    def compile!
      require_template_library 'sass' unless defined?(::Sass::Engine)
      @engine = ::Sass::Engine.new(data, sass_options)
    end

    def evaluate(scope, locals, &block)
      @engine.render
    end

  private
    def sass_options
      options.merge(:filename => eval_file, :line => line)
    end
  end
  register 'sass', SassTemplate


  # Builder template implementation. See:
  # http://builder.rubyforge.org/
  class BuilderTemplate < Template
    def compile!
      require_template_library 'builder' unless defined?(::Builder)
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
  # LiquidTemplate does not support scopes or yield blocks.
  #
  # It's suggested that your program require 'liquid' at load
  # time when using this template engine.
  class LiquidTemplate < Template
    def compile!
      require_template_library 'liquid' unless defined?(::Liquid::Template)
      @engine = ::Liquid::Template.parse(data)
    end

    def evaluate(scope, locals, &block)
      locals = locals.inject({}) { |hash,(k,v)| hash[k.to_s] = v ; hash }
      @engine.render(locals)
    end
  end
  register 'liquid', LiquidTemplate


  # Discount Markdown implementation.
  class RDiscountTemplate < Template
    def compile!
      require_template_library 'rdiscount' unless defined?(::RDiscount)
      @engine = RDiscount.new(data)
    end

    def evaluate(scope, locals, &block)
      @engine.to_html
    end
  end
  register 'markdown', RDiscountTemplate
  register 'md', RDiscountTemplate


  # Mustache is written and maintained by Chris Wanstrath. See:
  # http://github.com/defunkt/mustache
  #
  # When a scope argument is provided to MustacheTemplate#render, the
  # instance variables are copied from the scope object to the Mustache
  # view.
  class MustacheTemplate < Template
    attr_reader :engine

    # Locates and compiles the Mustache object used to create new views. The
    def compile!
      require_template_library 'mustache' unless defined?(::Mustache)

      # Set the Mustache view namespace if we can
      Mustache.view_namespace = options[:namespace]

      # Figure out which Mustache class to use.
      @engine = options[:view] || Mustache.view_class(name)

      # set options on the view class
      options.each do |key, value|
        next if %w[view namespace mustaches].include?(key.to_s)
        @engine.send("#{key}=", value) if @engine.respond_to? "#{key}="
      end
    end

    def evaluate(scope=nil, locals={}, &block)
      # Create a new instance for playing with
      instance = @engine.new

      # Copy instance variables from scope to the view
      scope.instance_variables.each do |name|
        instance.instance_variable_set(name, scope.instance_variable_get(name))
      end

      # Locals get added to the view's context
      locals.each do |local, value|
        instance[local] = value
      end

      # If we're passed a block it's a subview. Sticking it in yield
      # lets us use {{yield}} in layout.html to render the actual page.
      instance[:yield] = block.call if block

      instance.template = data unless instance.compiled?

      instance.to_html
    end
  end
  register 'mustache', MustacheTemplate
end
