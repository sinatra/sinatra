module Sinatra
  
  class Logger
    
    def initialize(steam)
      @stream = steam
    end
    
    %w(info debug error warn).each do |n|
      define_method n do |message|
        @stream.puts message
        @stream.flush
      end
    end
    
    def exception(e)
      error "#{e.message}:\n\t#{e.backtrace.join("\n\t")}"
    end
    
  end
  
end