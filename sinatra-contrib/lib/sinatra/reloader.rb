require 'sinatra/base'

module Sinatra
  # Extension to reload modified files.  In the development
  # environment, it will automatically require files defining routes
  # with every incoming request, but you can refine the reloading
  # policy with +also_reload+ and +dont_reload+, to customize which
  # files should, and should not, be reloaded, respectively.
  module Reloader
    # Watches a file so it can tell when it has been updated.  It also
    # knows the routes defined and if it contains inline templates.
    class Watcher
      # Represents an element of a Sinatra application that needs to be
      # reloaded.
      #
      # Its +representation+ attribute is there to allow to identify the
      # element within an application, that is, to match it with its
      # Sinatra's internal representation.
      class Element < Struct.new(:type, :representation)
      end

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

        # Lets the +Watcher+ for the file localted at +path+ know that the
        # +element+ is defined there, and adds the +Watcher+ to the +List+, if
        # it isn't already there.
        def watch(path, element)
          watcher_for(path).elements << element
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

      attr_reader :path, :elements, :mtime

      # Creates a new +Watcher+ instance for the file located at
      # +path+.
      def initialize(path)
        @path, @elements = path, []
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
        watcher.elements.each { |element| klass.deactivate(element) }
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
        Watcher::List.for(self).watch(source_location, Watcher::Element.new(
          :route, { :verb => verb, :signature => signature }
        ))
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

      # Does everything Sinatra::Base#use does, but it also tells the
      # +Watcher::List+ for the Sinatra application to watch the
      # middleware beign used.
      def use(middleware, *args, &block)
        path = caller_files[1] || File.expand_path($0)
        Watcher::List.for(self).watch(path, Watcher::Element.new(
          :middleware, [middleware, args, block]
        ))
        super
      end
    end

    # Contains the methods that the extension adds to the Sinatra
    # application.
    module ExtensionMethods
      # Removes the +element+ from the Sinatra application.
      def deactivate(element)
        case element.type
        when :route then
          verb      = element.representation[:verb]
          signature = element.representation[:signature]
          (routes[verb] ||= []).delete(signature)
        when :middleware then
          @middleware.delete(element.representation)
        end
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
