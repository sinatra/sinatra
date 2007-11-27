require File.dirname(__FILE__) + '/test/methods'

Object.send(:include, Sinatra::Test::Methods) # added to allow post_to in console

Object.class_eval do

  # Reload all Sinatra and App specific files
  def reload!
    Sinatra.reload!
  end

  # Show the +body+ with result info in your text editor!!! Great Job!
  def show!(editor = nil)
    editor = editor || ENV['EDITOR']
    IO.popen(editor, 'w') do |f| 
      f.puts "<!--"
      f.puts result_info
      f.puts "-->"
      f.puts
      f.puts body
    end
    nil
  end
  alias :mate :show!

  def result_info #:nodoc:
    info = <<-end_info
    # Status: #{status}
    # Headers: #{headers.inspect}
    end_info
  end

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
