module Sinatra
  
  DEFAULT_HEADERS = { 'Content-Type' => 'text/html' }
  
  class Dispatcher

    cattr_accessor :logger
        
    def headers
      DEFAULT_HEADERS
    end

    def call(env)
      @request = Rack::Request.new(env)
      
      event = EventManager.determine_event(
        @request.request_method.downcase.intern, 
        @request.path_info
      )
      
      result = event.attend(@request)
      [result.status, headers.merge(result.headers), result.body]
    rescue => e
      logger.exception e
    end
    
  end
  
end
