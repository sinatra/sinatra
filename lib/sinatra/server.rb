module Sinatra
  
  class Server
    
    cattr_accessor :logger
    cattr_accessor :running
    
    def start
      begin
        Rack::Handler::Mongrel.run(Sinatra::Dispatcher.new, :Port => 4567) do |server|
          logger.info "== Sinatra has taken the stage on port #{server.port}!"
          trap("INT") do
            server.stop
            self.class.running = false
            logger.info "\n== Sinatra has ended his set (crowd applauds)"
          end
        end
        self.class.running = true
      rescue => e
        logger.exception e
      end
    end
        
  end
  
end
