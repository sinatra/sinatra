require 'pathname'

module Sinatra
  module Reloader
    class Route
      attr_accessor :app, :source_location, :verb, :signature

      def initialize(attrs={})
        self.app             = attrs[:app]
        self.source_location = attrs[:source_location]
        self.verb            = attrs[:verb]
        self.signature       = attrs[:signature]
      end
    end

    class Watcher
      @path_watcher_map ||= Hash.new { |hash, key| hash[key] = new(key) }

      def self.watcher_for(path)
        @path_watcher_map[Pathname.new(path).expand_path.to_s]
      end

      def self.watch_file(path)
        watcher_for(path)
      end

      def self.watch_route(route)
        watcher_for(route.source_location).routes << route
      end

      def self.watch_inline_templates(path, app)
        watcher_for(path).inline_templates(app)
      end

      def self.ignore(path)
        watcher_for(path).ignore
      end

      def self.watchers
        @path_watcher_map.values
      end

      def self.updated
        watchers.find_all(&:updated?)
      end

      attr_reader :path, :routes, :mtime
      attr_writer :app

      def initialize(path)
        @path, @routes = path, []
        update
      end

      def updated?
        !ignored? && mtime != File.mtime(path)
      end

      def update
        @mtime = File.mtime(path)
      end

      def inline_templates(app)
        @inline_templates = true
        @app = app
      end

      def inline_templates?
        !!@inline_templates
      end

      def ignore
        @ignore = true
      end

      def ignored?
        !!@ignore
      end

      def app
        @app || (routes.first.app unless routes.empty?) || Sinatra::Application
      end
    end

    def self.registered(klass)
      klass.extend BaseMethods
      klass.extend ExtensionMethods
      klass.enable :reload_templates
      klass.before { Reloader.perform }
    end

    def self.perform
      Watcher.updated.each do |watcher|
        if watcher.inline_templates?
          watcher.app.set(:inline_templates, watcher.path)
        end
        watcher.routes.each do |route|
          watcher.app.deactivate_route(route.verb, route.signature)
        end
        $LOADED_FEATURES.delete(watcher.path)
        require watcher.path
        watcher.update
      end
    end

    module BaseMethods
      def route(verb, path, options={}, &block)
        source_location = block.respond_to?(:source_location) ?
          block.source_location.first : caller_files.first
        super.tap do |signature|
          Watcher.watch_route Route.new(
             :app             => self,
             :source_location => source_location,
             :verb            => verb,
             :signature       => signature
           )
        end
      end

      def iniline_templates=(file=nil)
        file = (file.nil? || file == true) ?
          (caller_files.first || File.expand_path($0)) : file
        Watcher.watch_inline_templates(file, self)
        super
      end
    end

    module ExtensionMethods
      def deactivate_route(verb, signature)
        (routes[verb] ||= []).delete(signature)
      end

      def also_reload(glob)
        Dir[glob].each { |path| Watcher.watch_file(path) }
      end

      def dont_reload(glob)
        Dir[glob].each { |path| Watcher.ignore(path) }
      end
    end
  end

  register Reloader
  Delegator.delegate :also_reload, :dont_reload
end
