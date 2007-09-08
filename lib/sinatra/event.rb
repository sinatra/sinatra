module Sinatra
  
  module EventManager
    
    extend self

    def events
      @events || []
    end
    
    def register_event(event)
      (@events ||= []) << event
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
    
  end
  
  class Event

    cattr_accessor :logger
    
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
        log_event(request, context, nil)
        context
      rescue => e
        context.status 500
        log_event(request, context, e)
        context
      end
    end
    alias :call :attend

    private
    
      def log_event(request, context, e)
        logger.info "#{request.request_method} #{request.path_info} | Status: #{context.status} | Params: #{context.params.inspect}"
        logger.exception(e) if e
      end
    
  end
  
end
