module Sinatra
  
  module Responder
    
    def self.included(parent)
      parent.send(:include, InstanceMethods)
    end

    class ResponderContext
      def initialize(format)
        @format = format
      end
      
      def method_missing(name, *args)
        yield if name.to_s == @format
      end
    end

    module InstanceMethods
      def format
        @responder_context ||= ResponderContext.new(params[:format])
      end
    end
    
  end
  
end