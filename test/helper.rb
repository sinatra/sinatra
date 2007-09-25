require File.dirname(__FILE__) + '/../lib/sinatra'

%w(mocha test/spec).each do |library|
  begin
    require library
  rescue
    STDERR.puts "== Sinatra's tests need #{library} to run."
  end
end

Sinatra::Server.running = true
Sinatra::Options.set_environment :test
Sinatra::Environment.prepare_loggers

class Test::Unit::TestCase
  include Sinatra::TestMethods
end
