module Sinatra
  module Environment
    extend self
        
    def setup!
      Options.parse!(ARGV)
      set_loggers
    end

    def set_loggers(logger = Logger.new(open(Options.log_file, 'w')))
      [Server, EventContext, Event, Dispatcher].each do |klass|
        klass.logger = logger
      end
    end    
  end
end
