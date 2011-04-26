require 'sinatra/base'

module Sinatra
  # Extension to reload modified files.  In the development
  # environment, it will automatically require files defining routes
  # with every incoming request, but you can refine the reloading
  # policy with +also_reload+ and +dont_reload+, to customize which
  # files should, and should not, be reloaded, respectively.
  module Reloader
    # Represents a Sinatra route.
    class Route
      attr_accessor :app, :source_location, :verb, :signature

      # Creates a new Route instance, it expects a hash with the
      # Sinatra application (+:app+ key), the file in which the route
      # is defined (+:source_location+ key), its verb (+:verb+ key)
      # and its signature, or, in other words, the array used
      # internally by Sinatra to identify the route (+:signature+
      # key).
      def initialize(attrs={})
        self.app             = attrs[:app]
        self.source_location = attrs[:source_location]
        self.verb            = attrs[:verb]
        self.signature       = attrs[:signature]
      end
    end

    # Watches a file so it can tell when it has been updated.  It also
    # knows the routes defined and if it contains inline templates.
    class Watcher
      # Collection of file +Watcher+ that can be associated with a
      # Sinatra application.  That way, we can know which files belong
      # to a given application and which files have been modified.  It
      # also provides a mechanism to inform a Watcher the routes
      # defined in the file being watched, whether it has inline
      # templates and if it changes should be ignored.
      class List
        @app_list_map = Hash.new { |hash, key| hash[key] = new }

        # Returns (an creates if it doesn't exists) a +List+ for the
        # application +app+.
        def self.for(app)
          @app_list_map[app]
        end

        # Creates a new +List+ instance.
        def initialize
          @path_watcher_map = Hash.new do |hash, key|
            hash[key] = Watcher.new(key)
          end
        end

        # Lets the +Watcher+ for the file containing +route+ know that
        # the +route+ is defined there, and adds the +Watcher+ to the
        # +List+, if it isn't already there.
        def watch_route(route)
          watcher_for(route.source_location).routes << route
        end

        # Lets the +Watcher+ for the file located at +path+ know that
        # it contains inline templates, and adds the +Watcher+ to the
        # +List+, if it isn't already there.
        def watch_inline_templates(path)
          watcher_for(path).inline_templates
        end

        # Lets the +Watcher+ for the file located at +path+ to ignore
        # the file changes, and adds the +Watcher+ to the +List+, if
        # it isn't already there.
        def ignore(path)
          watcher_for(path).ignore
        end

        # Adds a +Watcher+ for the file located at +path+ to the
        # +List+, if it isn't already there.
        def watcher_for(path)
          @path_watcher_map[File.expand_path(path)]
        end
        alias watch_file watcher_for

        # Returns an array with all the watchers in the +List+.
        def watchers
          @path_watcher_map.values
        end

        # Returns an array with all the watchers in the +List+ that
        # have been updated.
        def updated
          watchers.find_all(&:updated?)
        end
      end

      attr_reader :path, :routes, :mtime

      # Creates a new +Watcher+ instance for the file located at
      # +path+.
      def initialize(path)
        @path, @routes = path, []
        update
      end

      # Indicates whether or not the file being watched has been
      # modified.
      def updated?
        !ignore? && !removed? && mtime != File.mtime(path)
      end

      # Updates the file being watched mtime.
      def update
        @mtime = File.mtime(path)
      end

      # Informs that the file being watched has inline templates.
      def inline_templates
        @inline_templates = true
      end

      # Indicates whether or not the file being watched has inline
      # templates.
      def inline_templates?
        !!@inline_templates
      end

      # Informs that the modifications to the file being watched
      # should be ignored.
      def ignore
        @ignore = true
      end

      # Indicates whether or not the modifications to the file being
      # watched should be ignored.
      def ignore?
        !!@ignore
      end

      # Indicates whether or not the file being watched has been
      # removed.
      def removed?
        !File.exist?(path)
      end
    end

    # When the extension is registed it extends the Sinatra
    # application +klass+ with the modules +BaseMethods+ and
    # +ExtensionMethods+ and defines a before filter to +perform+ the
    # reload of the modified file.
    def self.registered(klass)
      klass.extend BaseMethods
      klass.extend ExtensionMethods
      klass.set(:reloader) { klass.development? }
      klass.set(:reload_templates) { klass.reloader? }
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

    # Reloads the modified files, adding, updating and removing routes
    # and inline templates as apporpiate.
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

    # Indicates whether or not we can and need to run thread-safely.
    def self.thread_safe?
      Thread and Thread.list.size > 1 and Thread.respond_to?(:exclusive)
    end

    # Contains the methods defined in Sinatra::Base that are
    # overriden.
    module BaseMethods
      # Does everything Sinatra::Base#route does, but it also tells
      # the +Watcher::List+ for the Sinatra application to watch the
      # defined route.
      def route(verb, path, options={}, &block)
        source_location = block.respond_to?(:source_location) ?
          block.source_location.first : caller_files[1]
        signature = super
        Watcher::List.for(self).watch_route Route.new(
           :app             => self,
           :source_location => source_location,
           :verb            => verb,
           :signature       => signature
        )
        signature
      end

      # Does everything Sinatra::Base#inline_templates= does, but it
      # also tells the +Watcher::List+ for the Sinatra application to
      # watch the inline templates in +file+ or the file who made the
      # call to his method.
      def inline_templates=(file=nil)
        file = (file.nil? || file == true) ?
          (caller_files[1] || File.expand_path($0)) : file
        Watcher::List.for(self).watch_inline_templates(file)
        super
      end
    end

    # Contains the methods that the extension adds to the Sinatra
    # application.
    module ExtensionMethods
      # Deactivates the route with the corresponding +verb+ and
      # +signature+ (this is the array Sinatra uses to store the
      # routes internally).
      def deactivate_route(verb, signature)
        (routes[verb] ||= []).delete(signature)
      end

      # Indicates with a +glob+ which files should be reloaded if they
      # have been modified.  It can be called several times.
      def also_reload(glob)
        Dir[glob].each { |path| Watcher::List.for(self).watch_file(path) }
      end

      # Indicates with a +glob+ which files should not be reloaded
      # event if they have been modified.  It can be called several
      # times.
      def dont_reload(glob)
        Dir[glob].each { |path| Watcher::List.for(self).ignore(path) }
      end
    end
  end

  register Reloader
  Delegator.delegate :also_reload, :dont_reload
end
