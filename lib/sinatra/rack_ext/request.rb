module Rack #:nodoc:
  
  class Request #:nodoc:
    
    def request_method
      if @env['REQUEST_METHOD'] == 'POST' && %w(PUT DELETE).include?(params['_method'])
        params['_method'].upcase
      else
        @env['REQUEST_METHOD']
      end
    end
    
  end
  
end
