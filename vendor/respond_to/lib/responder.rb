module Sinatra
  module Responder

    module InstanceMethods
      def method_missing(id, *args, &block)
        if block
          @responds_to[id] = block unless @responds_to.has_key? id
        else
          super
        end
      end
      def initialize_with_responds_to(i)
        initialize_without_responds_to(i)
        @responds_to = {}
      end
    end

    def self.included(base)
      base.send :include, InstanceMethods
      base.instance_eval do
        alias_method :initialize_without_responds_to, :initialize
        alias_method :initialize, :initialize_with_responds_to
      end
      attr_accessor :responds_to
    end
  end
  module EventResponder
    def self.included(base)
      base.send :include, InstanceMethods
      base.instance_eval do
        alias_method :attend_without_respond_to, :attend
        alias_method :attend, :attend_with_respond_to
      end
    end
    module InstanceMethods
      # Pulls the request info from the REQUEST_PATH
      #  it looks for the path extension
      #  For instance, index.html will respond to the html block
      def respond_request(request)
        request.env['REQUEST_PATH'].include?('.') ? request.env['REQUEST_PATH'].split('.')[-1].to_sym : :html
      end
      def attend_with_respond_to(request)
        context = EventContext.new(request)
        begin
          context.instance_eval(&@block) if @block
          context.responds_to[respond_request(request)].call if context.responds_to.has_key? respond_request(request)
        rescue => e
          context.error e
        end
        run_through_after_filters(context)
        context
      end
    end
  end

  module DispatcherResponder
    def determine_event(verb, path)
      EventManager.events.detect(method(:not_found)) do |e|
        e.path =~ Regexp.new(path.split(".")[0..-2].join("|").gsub(/\//, '')) && e.verb == verb
      end
    end
  end
end
