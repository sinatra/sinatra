%w(rubygems rack).each do |library|
  begin
    require library
  rescue LoadError
    raise "== Sinatra cannot run without #{library} installed"
  end
end

SINATRA_ROOT = File.dirname(__FILE__) + '/..'

require File.dirname(__FILE__) + '/sinatra/loader'

Sinatra::Loader.load_files Dir.glob(SINATRA_ROOT + '/lib/sinatra/core_ext/*.rb')
Sinatra::Loader.load_files Dir.glob(SINATRA_ROOT + '/lib/sinatra/*.rb')
Sinatra::Loader.load_files Dir.glob(SINATRA_ROOT + '/vendor/*/init.rb')

SINATRA_LOGGER = Sinatra::Logger.new(STDOUT)

def set_logger(logger = SINATRA_LOGGER)
  [Sinatra::Server, Sinatra::EventContext, Sinatra::Event, Sinatra::Dispatcher].each do |klass|
    klass.logger = logger
  end
end

set_logger

at_exit do
  Sinatra::Server.new.start unless Sinatra::Server.running
end
