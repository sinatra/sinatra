require 'fileutils'

module Sinatra
  
  class Server
    
    cattr_accessor :logger
    cattr_accessor :running
    
    def start
      begin
        setup_environment
        tail_thread = tail(Options.log_file)
        Rack::Handler::Mongrel.run(Dispatcher.new, :Port => Options.port) do |server|
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
      ensure
        tail_thread.kill if tail_thread
      end
    end
        
    private 
  
      def setup_environment
        Options.parse!(ARGV)
        set_loggers
      end
    
      def set_loggers
        logger = Logger.new(open(Options.log_file, 'w'))
        [Server, EventContext, Event, Dispatcher].each do |klass|
          klass.logger = logger
        end
      end
      
      def tail(log_file)
        FileUtils.touch(log_file)
        cursor = File.size(log_file)
        last_checked = Time.now
        tail_thread = Thread.new do
          File.open(log_file, 'r') do |f|
            loop do
              f.seek cursor
              if f.mtime > last_checked
                last_checked = f.mtime
                contents = f.read
                cursor += contents.length
                print contents
              end
              sleep 1
            end
          end
        end
        tail_thread
      end
      
  end
  
end
