require File.dirname(__FILE__) + '/context/renderer'

module Sinatra

  class EventContext
  
    cattr_accessor :logger
    attr_reader :request

    include Sinatra::Renderer
  
    def initialize(request)
      @request = request
      @headers = {}
    end
  
    def status(value = nil)
      @status = value if value
      @status || 200
    end
  
    def body(value = nil, &block)
      @body = value if value
      @body = block.call if block
      @body
    end
  
    def error(value = nil)
      if value
        status 500
        @error = value
        erb :error, :views_directory => SINATRA_ROOT + '/files/'
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
  
    def session
      request.env['rack.session']
    end

    def params
      @params ||= @request.params.symbolize_keys
    end
    
    def redirect(path)
      logger.info "Redirecting to: #{path}"
      status 302
      header 'Location' => path
    end
  
    def log_event
      logger.info "#{request.request_method} #{request.path_info} | Status: #{status} | Params: #{params.inspect}"
      logger.exception(error) if error
    end
  
  end

end
