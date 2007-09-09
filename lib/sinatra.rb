%w(rubygems rack).each do |library|
  begin
    require library
  rescue LoadError
    raise "== Sinatra cannot run without #{library} installed"
  end
end

require File.dirname(__FILE__) + '/sinatra/core_ext/class'
require File.dirname(__FILE__) + '/sinatra/core_ext/hash'

require File.dirname(__FILE__) + '/sinatra/logger'
require File.dirname(__FILE__) + '/sinatra/event'
require File.dirname(__FILE__) + '/sinatra/dispatcher'
require File.dirname(__FILE__) + '/sinatra/server'
require File.dirname(__FILE__) + '/sinatra/dsl'

SINATRA_LOGGER = Sinatra::Logger.new(STDOUT)

def set_logger(logger = SINATRA_LOGGER)
  [Sinatra::Server, Sinatra::EventContext, Sinatra::Event, Sinatra::Dispatcher].each do |klass|
    klass.logger = logger
  end
end

set_logger

SINATRA_ROOT = File.dirname(__FILE__) + '/..'

Dir.glob(SINATRA_ROOT + '/vendor/*/init.rb').each do |plugin|
  require plugin
end

at_exit do
  Sinatra::Server.new.start unless Sinatra::Server.running
end
