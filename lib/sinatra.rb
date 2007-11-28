
module Sinatra

  Result = Struct.new(:body)
  
  class Event
    
    attr_reader :path, :block
    
    def initialize(path, &b)
      @path = path
      @block = b
    end
    
    def invoke
      Result.new(block.call)
    end
    
  end
  
  class Application
    
    attr_reader :events
    
    def initialize
      @events = Hash.new { |hash, key| hash[key] = [] }
    end
    
    def define_event(method, path, &b)
      events[method] << event = Event.new(path, &b)
      event
    end
    
    def lookup(method, path)
      events[method].find do |e| 
        result = e.invoke and break result
      end
    end
    
  end
  
end