module Sinatra
  
  module EventManager
    
    extend self

    def events
      @events || []
    end
    
    def register_event(event)
      (@events ||= []) << event
    end
    
    def determine_event(verb, path)
      EventManager.events.detect(method(:not_found)) do |e| 
        e.path == path && e.verb == verb
      end
    end
    
    def not_found
      Event.new(:get, nil) do
        status 404
        views_dir SINATRA_ROOT + '/files'
    
        if request.path_info == '/'
          erb :default_index
        else
          erb :not_found
        end
      end
    end
    
  end
  
  class EventContext

    cattr_accessor :logger
    
    attr_reader :request
    
    def initialize(request)
      @request = request
      @headers = {}
    end
    
    def status(value = nil)
      @status = value if value
      @status || 200
    end
    
    def body(value = nil)
      @body = value if value
      @body || ''
    end
    
    def error(value = nil)
      if value
        @error = value
        status 500
      end
      @error
    end
        
    # This allows for:
    #  header 'Content-Type' => 'text/html'
    #  header 'Foo' => 'Bar'
    # or
    #  headers 'Content-Type' => 'text/html',
    #          'Foo' => 'Bar'
    # 
    # Whatever blows your hair back
    def headers(value = nil)
      @headers.merge!(value) if value
      @headers
    end
    alias :header :headers
    
    def params
      @params ||= @request.params.symbolize_keys
    end
    
    def log_event
      logger.info "#{request.request_method} #{request.path_info} | Status: #{status} | Params: #{params.inspect}"
      logger.exception(error) if error
    end
    
  end
  
  class Event

    cattr_accessor :logger
    cattr_accessor :after_filters
    
    self.after_filters = []
    
    def self.after_attend(filter)
      after_filters << filter
    end
    
    after_attend :log_event
    
    attr_reader :path, :verb
    
    def initialize(verb, path, &block)
      @verb = verb
      @path = path
      @block = block
      EventManager.register_event(self)
    end
    
    def attend(request)
      begin
        context = EventContext.new(request)
        context.instance_eval(&@block) if @block
        context
      rescue => e
        context.error e
      end
      run_through_after_filters(context)
      context
    end
    alias :call :attend

    private
    
      def run_through_after_filters(context)
        after_filters.each { |filter| context.send(filter) }
      end
  end
  
end
