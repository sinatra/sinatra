require 'optparse'

module Sinatra
  module Options
    extend self
    
    attr_with_default :port, 4567
    attr_with_default :environment, :development
    attr_with_default :console, nil

    def parse!(args)
      return if @environment == :test
      OptionParser.new do |opts|
        opts.on '-p port', '--port port', 'Set the port (default is 4567)' do |port|
          @port = port
        end
        opts.on '-e environment', 'Set the environment (default if development)' do |env|
          @environment = env.intern
        end
        opts.on '-c', '--console', 'Run in console mode' do
          @console = true
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
    
    def set_environment(env)
      @environment = env
    end
  end
end
