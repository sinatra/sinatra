require 'erb'

module Sinatra
  
  module Erb
    
    module InstanceMethods
      
      def erb(content)
        s = if content.is_a?(Symbol)
          open("%s/%s.erb" % [views_dir, content]).read
        else
          content
        end
        body ERB.new(s).result(binding)
      end
      
      def views_dir(value = nil)
        @views_dir = value if value
        @views_dir || File.dirname($0) + '/views'
      end
      
    end
    
  end
  
end
