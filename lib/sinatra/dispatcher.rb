module Sinatra
  
  DEFAULT_HEADERS = { 'Content-Type' => 'text/html' }
  
  class Dispatcher
        
    def headers
      DEFAULT_HEADERS
    end

    def call(env)
      @request = Rack::Request.new(env)
      
      event = EventManager.events.detect(lambda { not_found }) do |e| 
        e.path == @request.path_info && e.verb == @request.request_method.downcase.intern
      end
      
      result = event.attend(@request)
            
      [result.status, headers.merge(result.headers), result.body]
    rescue => e
      puts "#{e.message}:\n\t#{e.backtrace.join("\n\t")}"
    end
    
    private
    
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
  
end
