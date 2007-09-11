module Sinatra
  module Irb
    extend self

    # taken from merb
    def start!
      
      Object.send(:include, TestMethods) # added to allow post_to in console
      
      ARGV.clear # Avoid passing args to IRB 
      require 'irb' 
      require 'irb/completion' 
      def exit
        exit!
      end   
      if File.exists? ".irbrc"
        ENV['IRBRC'] = ".irbrc"
      end
      IRB.start
      exit!
    end
  end
end
