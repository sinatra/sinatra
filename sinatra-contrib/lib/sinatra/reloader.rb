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
      class List
        @app_list_map = Hash.new { |hash, key| hash[key] = new }

        def self.for(app)
          @app_list_map[app]
        end

        def initialize
          @path_watcher_map = Hash.new do |hash, key|
            hash[key] = Watcher.new(key)
          end
        end

        def watch_route(route)
          watcher_for(route.source_location).routes << route
        end

        def watch_inline_templates(path)
          watcher_for(path).inline_templates
        end

        def ignore(path)
          watcher_for(path).ignore
        end

        def watcher_for(path)
          @path_watcher_map[Pathname.new(path).expand_path.to_s]
        end
        alias watch_file watcher_for

        def watchers
          @path_watcher_map.values
        end

        def updated
          watchers.find_all(&:updated?)
        end
      end

      attr_reader :path, :routes, :mtime

      def initialize(path)
        @path, @routes = path, []
        update
      end

      def updated?
        !ignore? && mtime != File.mtime(path)
      end

      def update
        @mtime = File.mtime(path)
      end

      def inline_templates
        @inline_templates = true
      end

      def inline_templates?
        !!@inline_templates
      end

      def ignore
        @ignore = true
      end

      def ignore?
        !!@ignore
      end
    end

    def self.registered(klass)
      klass.extend BaseMethods
      klass.extend ExtensionMethods
      klass.enable :reload_templates
      klass.set(:reloader) { klass.development? }
      klass.before do
        if klass.reloader?
          if Reloader.thread_safe?
            Thread.exclusive { Reloader.perform(klass) }
          else
            Reloader.perform(klass)
          end
        end
      end
    end

    def self.perform(klass)
      Watcher::List.for(klass).updated.each do |watcher|
        klass.set(:inline_templates, watcher.path) if watcher.inline_templates?
        watcher.routes.each do |route|
          klass.deactivate_route(route.verb, route.signature)
        end
        $LOADED_FEATURES.delete(watcher.path)
        require watcher.path
        watcher.update
      end
    end

    def self.thread_safe?
      Thread and Thread.list.size > 1 and Thread.respond_to?(:exclusive)
    end

    module BaseMethods
      def route(verb, path, options={}, &block)
        source_location = block.respond_to?(:source_location) ?
          block.source_location.first : caller_files.first
        super.tap do |signature|
          Watcher::List.for(self).watch_route Route.new(
             :app             => self,
             :source_location => source_location,
             :verb            => verb,
             :signature       => signature
           )
        end
      end

      def inline_templates=(file=nil)
        file = (file.nil? || file == true) ?
          (caller_files[1] || File.expand_path($0)) : file
        Watcher::List.for(self).watch_inline_templates(file)
        super
      end
    end

    module ExtensionMethods
      def deactivate_route(verb, signature)
        (routes[verb] ||= []).delete(signature)
      end

      def also_reload(glob)
        Dir[glob].each { |path| Watcher::List.for(self).watch_file(path) }
      end

      def dont_reload(glob)
        Dir[glob].each { |path| Watcher::List.for(self).ignore(path) }
      end
    end
  end

  register Reloader
  Delegator.delegate :also_reload, :dont_reload
end
