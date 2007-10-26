require File.dirname(__FILE__) + '/context/renderer'

module Sinatra

  class EventContext
  
    cattr_accessor :logger
    attr_reader :request, :response

    include Sinatra::Renderer
  
    def initialize(request) #:nodoc:
      @request = request
      @response = Rack::Response.new
      @response.body = nil
    end
  
    # Sets or returns the status
    def status(value = nil)
      @response.status = value if value
      @response.status || 200
    end
  
    # Sets or returns the body
    # *Usage*
    #   body 'test'
    # or
    #   body do
    #     'test'
    #   end
    # both are the same
    #
    def body(value = nil, &block)
      @response.body = value if value
      @response.body = block.call if block
      @response.body
    end
    
    # Renders an exception to +body+ and sets status to 500
    def error(value = nil)
      if value
        status 500
        @error = value
        erb :error, :views_directory => SINATRA_ROOT + '/files/'
      end
      @error
    end
    
    def set_cookie(key, value)
      @response.set_cookie(key, value)
    end
    
    def delete_cookie(key, value)
      @response.delete_cookie(key, value)
    end
    
    # Sets or returns response headers
    #
    # *Usage*
    #   header 'Content-Type' => 'text/html'
    #   header 'Foo' => 'Bar'
    # or
    #   headers 'Content-Type' => 'text/html',
    #           'Foo' => 'Bar'
    # 
    # Whatever blows your hair back
    def headers(value = nil)
      @response.headers.merge!(value) if value
      @response.headers
    end
    alias :header :headers
  
    # Returns a Hash of params.  Keys are symbolized
    def params
      @params ||= @request.params.symbolize_keys
    end
    
    # Redirect to a url
    def redirect(path)
      logger.info "Redirecting to: #{path}"
      status 302
      header 'Location' => path
    end
  
    def log_event #:nodoc:
      logger.info "#{request.request_method} #{request.path_info} | Status: #{status} | Params: #{params.inspect}"
      logger.exception(error) if error
    end
  
  end

end
