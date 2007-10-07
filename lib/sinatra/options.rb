require 'optparse'

module Sinatra
  module Options
    extend self
    
    attr_with_default :port, 4567
    attr_with_default :environment, :development
    attr_with_default :console, nil
    attr_with_default :use_mutex, false

    alias :use_mutex? :use_mutex

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
        opts.on '-X', '--mutex', 'Use mutex lock when attending events' do
          @use_mutex = true
        end
      end.parse!(ARGV)
    end
    
    def log_file
      # TODO find a better way that this
      if File.basename($0, '.rb') == 'rake_test_loader'  # hack to satisfy rake
        '%s.log' % environment
      else
        File.dirname($0) + ('/%s.log' % environment)
      end
    end
    
    def set_environment(env)
      @environment = env
    end
  end
end
