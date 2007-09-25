module Sinatra
  module Environment
    extend self
        
    def prepare
      Options.parse!(ARGV)
    end

    def prepare_loggers(logger = Logger.new(open(Options.log_file, 'w')))
      [Server, EventContext, Event, Dispatcher].each do |klass|
        klass.logger = logger
      end
    end    
  end
end
