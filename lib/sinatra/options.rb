require 'optparse'

module Sinatra
  module Options
    extend self
    
    attr_with_default :port, 4567
    attr_with_default :environment, :development

    def parse!(args)
      OptionParser.new do |opts|
        opts.on '-p port', '--port port', 'Set the port (default is 4567)' do |port|
          @port = port
        end
        opts.on '-e environment', 'Set the environment (default if development)' do |env|
          @environment = env
        end
        opts.on '-h', '--help', '-?', 'Show this message' do
          puts opts
          exit!
        end
      end.parse!(ARGV)
    end
    
    def log_file
      File.dirname($0) + ('/%s.log' % environment)
    end
  end
end
