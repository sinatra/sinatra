require 'backports'
require 'sinatra/base'
require 'sinatra/decompile'

module Sinatra

  # = Sinatra::Namespace
  #
  # <tt>Sinatra::Namespace</tt> is an extension that adds namespaces to an
  # application.  This namespaces will allow you to share a path prefix for the
  # routes within the namespace, and define filters, conditions and error
  # handlers exclusively for them.  Besides that, you can also register helpers
  # and extensions that will be used only within the namespace.
  #
  # == Usage
  #
  # Once you have loaded the extension (see below), you can use the +namespace+
  # method to define namespaces in your application.
  #
  # You can define a namespace by a path prefix:
  #
  #     namespace '/blog' do
  #       get { haml :blog }
  #       get '/:entry_permalink' do
  #         @entry = Entry.find_by_permalink!(params[:entry_permalink])
  #         haml :entry
  #       end
  #
  #       # More blog routes...
  #     end
  #
  # by a condition:
  #
  #     namespace :host_name => 'localhost' do
  #       get('/admin/dashboard') { haml :dashboard }
  #       get('/admin/login')     { haml :login }
  #
  #       # More admin routes...
  #     end
  #
  # or both:
  #
  #     namespace '/admin', :host_name => 'localhost' do
  #       get('/dashboard')  { haml :dashboard }
  #       get('/login')      { haml :login }
  #       post('/login')     { login_user }
  #
  #       # More admin routes...
  #     end
  #
  # When you define a filter or an error handler, or register an extension or a
  # set of helpers within a namespace, they only affect the routes defined in
  # it.  For instance, lets define a before filter to prevent the access of
  # unauthorized users to the admin section of the application:
  #
  #     namespace '/admin' do
  #       helpers AdminHelpers
  #       before  { authenticate unless request.path_info == '/admin/login' }
  #
  #       get '/dashboard' do
  #         # Only authenticated users can access here...
  #         haml :dashboard
  #       end
  #
  #       # More admin routes...
  #     end
  #
  #     get '/' do
  #       # Any user can access here...
  #       haml :index
  #     end
  #
  # Well, they actually also affect the nested namespaces:
  #
  #     namespace '/admin' do
  #       helpers AdminHelpers
  #       before  { authenticate unless request.path_info == '/admin/login' }
  #
  #       namespace '/users' do
  #         get do
  #           # Only authenticated users can access here...
  #           @users = User.all
  #           haml :users
  #         end
  #
  #         # More user admin routes...
  #       end
  #
  #       # More admin routes...
  #     end
  #
  # === Classic Application Setup
  #
  # To be able to use namespaces in a classic application all you need to do is
  # require the extension:
  #
  #     require "sinatra"
  #     require "sinatra/namespace"
  #
  #     # The rest of your classic application code goes here...
  #
  # === Modular Application Setup
  #
  # To be able to use namespaces in a modular application all you need to do is
  # require the extension, and then, register it:
  #
  #     require "sinatra/base"
  #     require "sinatra/namespace"
  #
  #     class MyApp < Sinatra::Base
  #       register Sinatra::Namespace
  #
  #       # The rest of your modular application code goes here...
  #     end
  #
  module Namespace
    def self.new(base, pattern, conditions = {}, &block)
      Module.new do
        #quelch uninitialized variable warnings, since these get used by compile method.
        @pattern, @conditions = nil, nil
        extend NamespacedMethods
        include InstanceMethods
        @base, @extensions, @errors = base, [], {}
        @pattern, @conditions = compile(pattern, conditions)
        @templates            = Hash.new { |h,k| @base.templates[k] }
        namespace = self
        before { extend(@namespace = namespace) }
        class_eval(&block)
      end
    end

    module InstanceMethods
      def settings
        @namespace
      end

      def template_cache
        super.fetch(:nested, @namespace) { Tilt::Cache.new }
      end
    end

    module SharedMethods
      def namespace(pattern, conditions = {}, &block)
        Sinatra::Namespace.new(self, pattern, conditions, &block)
      end
    end

    module NamespacedMethods
      include SharedMethods
      include Sinatra::Decompile
      attr_reader :base, :templates

      def self.prefixed(*names)
        names.each { |n| define_method(n) { |*a, &b| prefixed(n, *a, &b) }}
      end

      prefixed :before, :after, :delete, :get, :head, :options, :patch, :post, :put

      def helpers(*extensions, &block)
        class_eval(&block) if block_given?
        include(*extensions) if extensions.any?
      end

      def register(*extensions, &block)
        extensions << Module.new(&block) if block_given?
        @extensions += extensions
        extensions.each do |extension|
          extend extension
          extension.registered(self) if extension.respond_to?(:registered)
        end
      end

      def invoke_hook(name, *args)
        @extensions.each { |e| e.send(name, *args) if e.respond_to?(name) }
      end

      def not_found(&block)
        error(Sinatra::NotFound, &block)
      end

      def errors
        base.errors.merge(namespace_errors)
      end

      def namespace_errors
        @errors
      end

      def error(*codes, &block)
        args  = Sinatra::Base.send(:compile!, "ERROR", regexpify(@pattern), block)
        codes = codes.map { |c| Array(c) }.flatten
        codes << Exception if codes.empty?

        codes.each do |c|
          errors = @errors[c] ||= []
          errors << args
        end
      end

      def respond_to(*args)
        return @conditions[:provides] || base.respond_to if args.empty?
        @conditions[:provides] = args
      end

      def set(key, value = self, &block)
        raise ArgumentError, "may not set #{key}" if key != :views
        return key.each { |k,v| set(k, v) } if block.nil? and value == self
        block ||= proc { value }
        singleton_class.send(:define_method, key, &block)
      end

      def enable(*opts)
        opts.each { |key| set(key, true) }
      end

      def disable(*opts)
        opts.each { |key| set(key, false) }
      end

      def template(name, &block)
        filename, line = caller_locations.first
        templates[name] = [block, filename, line.to_i]
      end

      def layout(name=:layout, &block)
        template name, &block
      end

      private

      def app
        base.respond_to?(:base) ? base.base : base
      end

      def compile(pattern, conditions, default_pattern = nil)
        if pattern.respond_to? :to_hash
          conditions = conditions.merge pattern.to_hash
          pattern = nil
        end
        base_pattern, base_conditions = @pattern, @conditions
        pattern         ||= default_pattern
        base_pattern    ||= base.pattern    if base.respond_to? :pattern
        base_conditions ||= base.conditions if base.respond_to? :conditions
        [ prefixed_path(base_pattern, pattern),
          (base_conditions || {}).merge(conditions) ]
      end

      def prefixed_path(a, b)
        return a || b || // unless a and b
        a, b = decompile(a), decompile(b) unless a.class == b.class
        a, b = regexpify(a), regexpify(b) unless a.class == b.class
        path = a.class.new "#{a}#{b}"
        path = /^#{path}$/ if path.is_a? Regexp and base == app
        path
      end

      def regexpify(pattern)
        pattern = Sinatra::Base.send(:compile, pattern).first.inspect
        pattern.gsub! /^\/(\^|\\A)?|(\$|\\z)?\/$/, ''
        Regexp.new pattern
      end

      def prefixed(method, pattern = nil, conditions = {}, &block)
        default = '*' if method == :before or method == :after
        pattern, conditions = compile pattern, conditions, default
        result = base.send(method, pattern, conditions, &block)
        invoke_hook :route_added, method.to_s.upcase, pattern, block
        result
      end

      def method_missing(method, *args, &block)
        base.send(method, *args, &block)
      end

      def respond_to?(method, include_private = false)
        super || base.respond_to?(method, include_private)
      end
    end

    module BaseMethods
      include SharedMethods
    end

    def self.extend_object(base)
      base.extend BaseMethods
    end
  end

  register Sinatra::Namespace
  Delegator.delegate :namespace
end
