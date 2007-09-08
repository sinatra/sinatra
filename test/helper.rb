require File.dirname(__FILE__) + '/../lib/sinatra'

%w(mocha test/spec).each do |library|
  begin
    require library
  rescue
    STDERR.puts "== Sinatra's tests need #{library} to run."
  end
end

Sinatra::Server.running = true

class Test::Unit::TestCase

  def get_it(path)
    request = Rack::MockRequest.new(Sinatra::Dispatcher.new)
    @response = request.get path
  end

  def post_it(path)
    request = Rack::MockRequest.new(Sinatra::Dispatcher.new)
    @response = request.post path
  end

  def response
    @response
  end

  def status
    @response.status
  end

  def text
    @response.body
  end

  def headers
    @response.headers
  end

end
