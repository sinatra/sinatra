module Sinatra
  class BadRequest < TypeError #:nodoc:
    def http_status; 400 end
  end

  class NotFound < NameError #:nodoc:
    def http_status; 404 end
  end
end
