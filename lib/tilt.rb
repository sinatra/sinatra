module Tilt
  @template_mappings = {}

  # Register a template implementation by file extension.
  def self.register(ext, template_class)
    ext = ext.sub(/^\./, '')
    @template_mappings[ext.downcase] = template_class
  end

  # Create a new template for the given file using the file's extension
  # to determine the the template mapping.
  def self.new(file, line=nil, options={}, &block)
    if template_class = self[File.basename(file)]
      template_class.new(file, line, options, &block)
    else
      fail "No template engine registered for #{File.basename(file)}"
    end
  end

  # Lookup a template class given for the given filename or file
  # extension. Return nil when no implementation is found.
  def self.[](filename)
    ext = filename.to_s.downcase
    until ext.empty?
      return @template_mappings[ext]  if @template_mappings.key?(ext)
      ext = ext.sub(/^[^.]*\.?/, '')
    end
    nil
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
      @file = file
      @line = line || 1
      @options = options || {}
      @reader = block || lambda { |t| File.read(file) }
    end

    # Render the template in the given scope with the locals specified. If a
    # block is given, it is typically available within the template via
    # +yield+.
    def render(scope=Object.new, locals={}, &block)
      if @data.nil?
        @data = @reader.call(self)
        compile!
      end
      evaluate scope, locals || {}, &block
    end

    # The filename used in backtraces to describe the template.
    def eval_file
      @file || '(__TEMPLATE__)'
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
      warn "WARN: loading '#{name}' library in a non thread-safe way; " +
           "explicit require '#{name}' suggested."
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
  #
  # It's suggested that your program require 'erb' at load
  # time when using this template engine.
  class ERBTemplate < Template
    def compile!
      require_template_library 'erb' unless defined?(::ERB)
      @engine = ::ERB.new(data, nil, nil, '@_out_buf')
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

  # Haml template implementation. See:
  # http://haml.hamptoncatlin.com/
  #
  # It's suggested that your program require 'haml' at load
  # time when using this template engine.
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
  #
  # It's suggested that your program require 'sass' at load
  # time when using this template engine.
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
  #
  # It's suggested that your program require 'builder' at load
  # time when using this template engine.
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

end
