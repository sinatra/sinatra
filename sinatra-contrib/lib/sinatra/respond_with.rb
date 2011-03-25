require 'sinatra/base'
require 'json' unless String.method_defined? :to_json

module Sinatra
  module RespondWith
    class Format
      def initialize(app)
        @app, @map, @generic, @default = app, {}, {}, nil
      end

      def on(type, &block)
        @app.settings.mime_types(type).each do |mime|
          case mime
          when '*/*'           then @default     = block
          when /^([^\/]+)\/\*$/ then @generic[$1] = block
          else                      @map[mime]   = block
          end
        end
      end

      def finish
        yield self if block_given?
        mime_type = @app.content_type             ||
          @app.request.preferred_type(@map.keys)  ||
          @app.request.preferred_type             ||
          'text/html'
        type = mime_type.split(/\s*;\s*/, 2).first
        handlers = [@map[type], @generic[type[/^[^\/]+/]], @default].compact
        handlers.each do |block|
          if result = block.call(type)
            @app.content_type mime_type
            @app.halt result
          end
        end
        @app.halt 406
      end

      def method_missing(meth, *args, &block)
        return super if args.any? or block.nil? or not @app.mime_type(meth)
        on(meth, &block)
      end
    end

    module Helpers
      def respond_with(template, object = nil, &block)
        object, template = template, nil unless Symbol === template
        format = Format.new(self)
        format.on "*/*" do |type|
          exts = settings.ext_map[type]
          exts << :xml if type.end_with? '+xml'
          if template
            args = template_cache.fetch(type, template) { template_for(template, exts) }
            if args.any?
              locals = { :object => object }
              locals.merge! object.to_hash if object.respond_to? :to_hash
              args << { :locals => locals }
              halt send(*args)
            end
          end
          if object
            exts.each do |ext|
              next unless meth = "to_#{ext}" and object.respond_to? meth
              halt(*object.send(meth))
            end
          end
          false
        end
        format.finish(&block)
      end

      def respond_to(&block)
        Format.new(self).finish(&block)
      end

      private

      def template_for(name, exts)
        # in production this is cached, so don't worry to much about runtime
        possible = []
        settings.template_engines[:all].each do |engine|
          exts.each { |ext| possible << [engine, "#{name}.#{ext}"] }
        end
        exts.each do |ext|
          settings.template_engines[ext].each { |e| possible << [e, name] }
        end
        possible.each do |engine, template|
          find_template(settings.views, template, Tilt[engine]) do |file|
            next unless File.exist? file
            return settings.rendering_method(engine) << template.to_sym
          end
        end
        [] # nil or false would not be cached
      end
    end

    attr_accessor :ext_map

    def remap_extensions
      ext_map.clear
      Rack::Mime::MIME_TYPES.each { |e,t| ext_map[t] << e[1..-1].to_sym }
      ext_map['text/javascript'] << 'js'
      ext_map['text/xml'] << 'xml'
    end

    def mime_type(*)
      result = super
      remap_extensions
      result
    end

    def respond_to(*formats, &block)
      if formats.any?
        @respond_to ||= []
        @respond_to.concat formats
      elsif @respond_to.nil? and superclass.respond_to? :respond_to
        superclass.respond_to
      else
        @respond_to
      end
    end

    def rendering_method(engine)
      return [engine] if Sinatra::Templates.method_defined? engine
      return [:mab] if engine.to_sym == :markaby
      [:render, :engine]
    end

    private

    def compile!(verb, path, block, options = {})
      options[:provides] ||= respond_to if respond_to
      super
    end

    ENGINES = {
      :css  => [:less,  :sass, :scss],
      :xml  => [:builder, :nokogiri],
      :js   => [:coffee],
      :html => [:erb, :erubis, :haml, :slim, :liquid, :radius, :mab, :markdown,
        :textile, :rdoc],
      :all  => Sinatra::Templates.instance_methods.map(&:to_sym) + [:mab] -
        [:find_template, :markaby]
    }

    ENGINES.default = []

    def self.registered(base)
      base.ext_map = Hash.new { |h,k| h[k] = [] }
      base.set :template_engines, ENGINES.dup
      base.remap_extensions
      base.helpers Helpers
    end
  end
end
