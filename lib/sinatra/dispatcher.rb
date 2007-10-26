module Sinatra
    
  class Dispatcher

    cattr_accessor :logger

    def call(env)
      Loader.reload! if Options.environment == :development
    
      @request = Rack::Request.new(env)
    
      event = EventManager.determine_event(
        @request.request_method.downcase.intern, 
        @request.path_info
      )
    
      result = event.attend(@request)
      result.response.to_a
    end
    
  end
  
end
