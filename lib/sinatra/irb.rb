module Sinatra
  module Irb
    extend self

    # taken from merb
    def start!
      
      Object.send(:include, TestMethods) # added to allow post_to in console
      
      Object.class_eval do
        def reload!
          Loader.reload!
        end
        
        def show!(editor = nil)
          editor = editor || ENV['EDITOR']
          IO.popen(editor, 'w') do |f| 
            f.puts "<!--"
            f.puts result_info
            f.puts "-->"
            f.puts
            f.puts body
          end
        end
        alias :mate :show!
      end
      
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
