module Sinatra
  # Template rendering methods. Each method takes the name of a template
  # to render as a Symbol and returns a String with the rendered output,
  # as well as an optional hash with additional options.
  #
  # `template` is either the name or path of the template as symbol
  # (Use `:'subdir/myview'` for views in subdirectories), or a string
  # that will be rendered.
  #
  # Possible options are:
  #   :content_type   The content type to use, same arguments as content_type.
  #   :layout         If set to something falsy, no layout is rendered, otherwise
  #                   the specified layout is used (Ignored for `sass` and `less`)
  #   :layout_engine  Engine to use for rendering the layout.
  #   :locals         A hash with local variables that should be available
  #                   in the template
  #   :scope          If set, template is evaluate with the binding of the given
  #                   object rather than the application instance.
  #   :views          Views directory to use.
  module Templates
    module ContentTyped
      attr_accessor :content_type
    end

    def initialize
      super
      @default_layout = :layout
      @preferred_extension = nil
    end

    def erb(template, options = {}, locals = {}, &block)
      render(:erb, template, options, locals, &block)
    end

    def erubis(template, options = {}, locals = {})
      warn "Sinatra::Templates#erubis is deprecated and will be removed, use #erb instead.\n" \
        "If you have Erubis installed, it will be used automatically."
      render :erubis, template, options, locals
    end

    def haml(template, options = {}, locals = {}, &block)
      render(:haml, template, options, locals, &block)
    end

    def sass(template, options = {}, locals = {})
      options.merge! :layout => false, :default_content_type => :css
      render :sass, template, options, locals
    end

    def scss(template, options = {}, locals = {})
      options.merge! :layout => false, :default_content_type => :css
      render :scss, template, options, locals
    end

    def less(template, options = {}, locals = {})
      options.merge! :layout => false, :default_content_type => :css
      render :less, template, options, locals
    end

    def stylus(template, options = {}, locals = {})
      options.merge! :layout => false, :default_content_type => :css
      render :styl, template, options, locals
    end

    def builder(template = nil, options = {}, locals = {}, &block)
      options[:default_content_type] = :xml
      render_ruby(:builder, template, options, locals, &block)
    end

    def liquid(template, options = {}, locals = {}, &block)
      render(:liquid, template, options, locals, &block)
    end

    def markdown(template, options = {}, locals = {})
      options[:exclude_outvar] = true
      render :markdown, template, options, locals
    end

    def textile(template, options = {}, locals = {})
      render :textile, template, options, locals
    end

    def rdoc(template, options = {}, locals = {})
      render :rdoc, template, options, locals
    end

    def asciidoc(template, options = {}, locals = {})
      render :asciidoc, template, options, locals
    end

    def radius(template, options = {}, locals = {})
      render :radius, template, options, locals
    end

    def markaby(template = nil, options = {}, locals = {}, &block)
      render_ruby(:mab, template, options, locals, &block)
    end

    def coffee(template, options = {}, locals = {})
      options.merge! :layout => false, :default_content_type => :js
      render :coffee, template, options, locals
    end

    def nokogiri(template = nil, options = {}, locals = {}, &block)
      options[:default_content_type] = :xml
      render_ruby(:nokogiri, template, options, locals, &block)
    end

    def slim(template, options = {}, locals = {}, &block)
      render(:slim, template, options, locals, &block)
    end

    def creole(template, options = {}, locals = {})
      render :creole, template, options, locals
    end

    def mediawiki(template, options = {}, locals = {})
      render :mediawiki, template, options, locals
    end

    def wlang(template, options = {}, locals = {}, &block)
      render(:wlang, template, options, locals, &block)
    end

    def yajl(template, options = {}, locals = {})
      options[:default_content_type] = :json
      render :yajl, template, options, locals
    end

    def rabl(template, options = {}, locals = {})
      Rabl.register!
      render :rabl, template, options, locals
    end

    # Calls the given block for every possible template file in views,
    # named name.ext, where ext is registered on engine.
    def find_template(views, name, engine)
      yield ::File.join(views, "#{name}.#{@preferred_extension}")

      Tilt.default_mapping.extensions_for(engine).each do |ext|
        yield ::File.join(views, "#{name}.#{ext}") unless ext == @preferred_extension
      end
    end

    private

    # logic shared between builder and nokogiri
    def render_ruby(engine, template, options = {}, locals = {}, &block)
      options, template = template, nil if template.is_a?(Hash)
      template = Proc.new { block } if template.nil?
      render engine, template, options, locals
    end

    def render(engine, data, options = {}, locals = {}, &block)
      # merge app-level options
      engine_options = settings.respond_to?(engine) ? settings.send(engine) : {}
      options.merge!(engine_options) { |key, v1, v2| v1 }

      # extract generic options
      locals          = options.delete(:locals) || locals         || {}
      views           = options.delete(:views)  || settings.views || "./views"
      layout          = options[:layout]
      layout          = false if layout.nil? && options.include?(:layout)
      eat_errors      = layout.nil?
      layout          = engine_options[:layout] if layout.nil? or (layout == true && engine_options[:layout] != false)
      layout          = @default_layout         if layout.nil? or layout == true
      layout_options  = options.delete(:layout_options) || {}
      content_type    = options.delete(:default_content_type)
      content_type    = options.delete(:content_type)   || content_type
      layout_engine   = options.delete(:layout_engine)  || engine
      scope           = options.delete(:scope)          || self
      exclude_outvar  = options.delete(:exclude_outvar)
      options.delete(:layout)

      # set some defaults
      options[:outvar] ||= '@_out_buf' unless exclude_outvar
      options[:default_encoding] ||= settings.default_encoding

      # compile and render template
      begin
        layout_was      = @default_layout
        @default_layout = false
        template        = compile_template(engine, data, options, views)
        output          = template.render(scope, locals, &block)
      ensure
        @default_layout = layout_was
      end

      # render layout
      if layout
        options = options.merge(:views => views, :layout => false, :eat_errors => eat_errors, :scope => scope).
                merge!(layout_options)
        catch(:layout_missing) { return render(layout_engine, layout, options, locals) { output } }
      end

      output.extend(ContentTyped).content_type = content_type if content_type
      output
    end

    def compile_template(engine, data, options, views)
      eat_errors = options.delete :eat_errors
      template_cache.fetch engine, data, options, views do
        template = Tilt[engine]
        raise "Template engine not found: #{engine}" if template.nil?

        case data
        when Symbol
          body, path, line = settings.templates[data]
          if body
            body = body.call if body.respond_to?(:call)
            template.new(path, line.to_i, options) { body }
          else
            found = false
            @preferred_extension = engine.to_s
            find_template(views, data, template) do |file|
              path ||= file # keep the initial path rather than the last one
              if found = File.exist?(file)
                path = file
                break
              end
            end
            throw :layout_missing if eat_errors and not found
            template.new(path, 1, options)
          end
        when Proc, String
          body = data.is_a?(String) ? Proc.new { data } : data
          caller = settings.caller_locations.first
          path = options[:path] || caller[0]
          line = options[:line] || caller[1]
          template.new(path, line.to_i, options, &body)
        else
          raise ArgumentError, "Sorry, don't know how to render #{data.inspect}."
        end
      end
    end
  end
end
