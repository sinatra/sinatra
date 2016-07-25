require 'sinatra/base'

module Sinatra

  # = Sinatra::Reloader
  #
  # Extension to reload modified files.  Useful during development,
  # since it will automatically require files defining routes, filters,
  # error handlers and inline templates, with every incoming request,
  # but only if they have been updated.
  #
  # == Usage
  #
  # === Classic Application
  #
  # To enable the reloader in a classic application all you need to do is
  # require it:
  #
  #     require "sinatra"
  #     require "sinatra/reloader" if development?
  #
  #     # Your classic application code goes here...
  #
  # === Modular Application
  #
  # To enable the reloader in a modular application all you need to do is
  # require it, and then, register it:
  #
  #     require "sinatra/base"
  #     require "sinatra/reloader"
  #
  #     class MyApp < Sinatra::Base
  #       configure :development do
  #         register Sinatra::Reloader
  #       end
  #
  #       # Your modular application code goes here...
  #     end
  #
  # == Using the Reloader in Other Environments
  #
  # By default, the reloader is only enabled for the development
  # environment. Similar to registering the reloader in a modular
  # application, a classic application requires manually enabling the
  # extension for it to be available in a non-development environment.
  #
  #      require "sinatra"
  #      require "sinatra/reloader"
  #
  #      configure :production do
  #        enable :reloader
  #      end
  #
  # == Changing the Reloading Policy
  #
  # You can refine the reloading policy with +also_reload+ and
  # +dont_reload+, to customize which files should, and should not, be
  # reloaded, respectively. You can also use +after_reload+ to execute a
  # block after any file being reloaded.
  #
  # === Classic Application
  #
  # Simply call the methods:
  #
  #     require "sinatra"
  #     require "sinatra/reloader" if development?
  #
  #     also_reload '/path/to/some/file'
  #     dont_reload '/path/to/other/file'
  #     after_reload do
  #       puts 'reloaded'
  #     end
  #
  #     # Your classic application code goes here...
  #
  # === Modular Application
  #
  # Call the methods inside the +configure+ block:
  #
  #     require "sinatra/base"
  #     require "sinatra/reloader"
  #
  #     class MyApp < Sinatra::Base
  #       configure :development do
  #         register Sinatra::Reloader
  #         also_reload '/path/to/some/file'
  #         dont_reload '/path/to/other/file'
  #         after_reload do
  #           puts 'reloaded'
  #         end
  #       end
  #
  #       # Your modular application code goes here...
  #     end
  #
  module Reloader

    # Watches a file so it can tell when it has been updated, and what
    # elements does it contain.
    class Watcher

      # Represents an element of a Sinatra application that may need to
      # be reloaded.  An element could be:
      # * a route
      # * a filter
      # * an error handler
      # * a middleware
      # * inline templates
      #
      # Its +representation+ attribute is there to allow to identify the
      # element within an application, that is, to match it with its
      # Sinatra's internal representation.
      class Element < Struct.new(:type, :representation)
      end

      # Collection of file +Watcher+ that can be associated with a
      # Sinatra application.  That way, we can know which files belong
      # to a given application and which files have been modified.  It
      # also provides a mechanism to inform a Watcher of the elements
      # defined in the file being watched and if its changes should be
      # ignored.
      class List
        @app_list_map = Hash.new { |hash, key| hash[key] = new }

        # Returns the +List+ for the application +app+.
        def self.for(app)
          @app_list_map[app]
        end

        # Creates a new +List+ instance.
        def initialize
          @path_watcher_map = Hash.new do |hash, key|
            hash[key] = Watcher.new(key)
          end
        end

        # Lets the +Watcher+ for the file located at +path+ know that the
        # +element+ is defined there, and adds the +Watcher+ to the +List+,
        # if it isn't already there.
        def watch(path, element)
          watcher_for(path).elements << element
        end

        # Tells the +Watcher+ for the file located at +path+ to ignore
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

      # Creates a new +Watcher+ instance for the file located at +path+.
      def initialize(path)
        @ignore = nil
        @path, @elements = path, []
        update
      end

      # Indicates whether or not the file being watched has been modified.
      def updated?
        !ignore? && !removed? && mtime != File.mtime(path)
      end

      # Updates the mtime of the file being watched.
      def update
        @mtime = File.mtime(path)
      end

      # Indicates whether or not the file being watched has inline
      # templates.
      def inline_templates?
        elements.any? { |element| element.type == :inline_templates }
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

      # Indicates whether or not the file being watched has been removed.
      def removed?
        !File.exist?(path)
      end
    end

    MUTEX_FOR_PERFORM = Mutex.new

    # Allow a block to be executed after any file being reloaded
    @@after_reload = []
    def after_reload(&block)
      @@after_reload  << block
    end

    # When the extension is registered it extends the Sinatra application
    # +klass+ with the modules +BaseMethods+ and +ExtensionMethods+ and
    # defines a before filter to +perform+ the reload of the modified files.
    def self.registered(klass)
      @reloader_loaded_in ||= {}
      return if @reloader_loaded_in[klass]

      @reloader_loaded_in[klass] = true

      klass.extend BaseMethods
      klass.extend ExtensionMethods
      klass.set(:reloader) { klass.development? }
      klass.set(:reload_templates) { klass.reloader? }
      klass.before do
        if klass.reloader?
          MUTEX_FOR_PERFORM.synchronize { Reloader.perform(klass) }
        end
      end
      klass.set(:inline_templates, klass.app_file) if klass == Sinatra::Application
    end

    # Reloads the modified files, adding, updating and removing the
    # needed elements.
    def self.perform(klass)
      Watcher::List.for(klass).updated.each do |watcher|
        klass.set(:inline_templates, watcher.path) if watcher.inline_templates?
        watcher.elements.each { |element| klass.deactivate(element) }
        $LOADED_FEATURES.delete(watcher.path)
        require watcher.path
        watcher.update
      end
      @@after_reload.each(&:call)
    end

    # Contains the methods defined in Sinatra::Base that are overridden.
    module BaseMethods
      # Protects Sinatra::Base.run! from being called more than once.
      def run!(*args)
        if settings.reloader?
          super unless running?
        else
          super
        end
      end

      # Does everything Sinatra::Base#route does, but it also tells the
      # +Watcher::List+ for the Sinatra application to watch the defined
      # route.
      #
      # Note: We are using #compile! so we don't interfere with extensions
      # changing #route.
      def compile!(verb, path, block, options = {})
        source_location = block.respond_to?(:source_location) ?
          block.source_location.first : caller_files[1]
        signature = super
        watch_element(
          source_location, :route, { :verb => verb, :signature => signature }
        )
        signature
      end

      # Does everything Sinatra::Base#inline_templates= does, but it also
      # tells the +Watcher::List+ for the Sinatra application to watch the
      # inline templates in +file+ or the file who made the call to this
      # method.
      def inline_templates=(file=nil)
        file = (file.nil? || file == true) ?
          (caller_files[1] || File.expand_path($0)) : file
        watch_element(file, :inline_templates)
        super
      end

      # Does everything Sinatra::Base#use does, but it also tells the
      # +Watcher::List+ for the Sinatra application to watch the middleware
      # being used.
      def use(middleware, *args, &block)
        path = caller_files[1] || File.expand_path($0)
        watch_element(path, :middleware, [middleware, args, block])
        super
      end

      # Does everything Sinatra::Base#add_filter does, but it also tells
      # the +Watcher::List+ for the Sinatra application to watch the defined
      # filter.
      def add_filter(type, path = nil, options = {}, &block)
        source_location = block.respond_to?(:source_location) ?
          block.source_location.first : caller_files[1]
        result = super
        watch_element(source_location, :"#{type}_filter", filters[type].last)
        result
      end

      # Does everything Sinatra::Base#error does, but it also tells the
      # +Watcher::List+ for the Sinatra application to watch the defined
      # error handler.
      def error(*codes, &block)
        path = caller_files[1] || File.expand_path($0)
        result = super
        codes.each do |c|
          watch_element(path, :error, :code => c, :handler => @errors[c])
        end
        result
      end

      # Does everything Sinatra::Base#register does, but it also lets the
      # reloader know that an extension is being registered, because the
      # elements defined in its +registered+ method need a special treatment.
      def register(*extensions, &block)
        start_registering_extension
        result = super
        stop_registering_extension
        result
      end

      # Does everything Sinatra::Base#register does and then registers the
      # reloader in the +subclass+.
      def inherited(subclass)
        result = super
        subclass.register Sinatra::Reloader
        result
      end
    end

    # Contains the methods that the extension adds to the Sinatra application.
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
        when :before_filter then
          filters[:before].delete(element.representation)
        when :after_filter then
          filters[:after].delete(element.representation)
        when :error then
          code    = element.representation[:code]
          handler = element.representation[:handler]
          @errors.delete(code) if @errors[code] == handler
        end
      end

      # Indicates with a +glob+ which files should be reloaded if they
      # have been modified.  It can be called several times.
      def also_reload(*glob)
        Dir[*glob].each { |path| Watcher::List.for(self).watch_file(path) }
      end

      # Indicates with a +glob+ which files should not be reloaded even if
      # they have been modified.  It can be called several times.
      def dont_reload(*glob)
        Dir[*glob].each { |path| Watcher::List.for(self).ignore(path) }
      end

    private

      # attr_reader :register_path warn on -w (private attribute)
      def register_path; @register_path ||= nil; end

      # Indicates an extesion is being registered.
      def start_registering_extension
        @register_path = caller_files[2]
      end

      # Indicates the extesion has already been registered.
      def stop_registering_extension
        @register_path = nil
      end

      # Indicates whether or not an extension is being registered.
      def registering_extension?
        !register_path.nil?
      end

      # Builds a Watcher::Element from +type+ and +representation+ and
      # tells the Watcher::List for the current application to watch it
      # in the file located at +path+.
      #
      # If an extension is being registered, it also tells the list to
      # watch it in the file where the extension has been registered.
      # This prevents the duplication of the elements added by the
      # extension in its +registered+ method with every reload.
      def watch_element(path, type, representation=nil)
        list = Watcher::List.for(self)
        element = Watcher::Element.new(type, representation)
        list.watch(path, element)
        list.watch(register_path, element) if registering_extension?
      end
    end
  end

  register Reloader
  Delegator.delegate :also_reload, :dont_reload
end
