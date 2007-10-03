require File.dirname(__FILE__) + '/../helper'

describe "Rack::Request" do
  it "should return PUT and DELETE based on _method param" do
    env = {'REQUEST_METHOD' => 'POST', 'rack.input' => StringIO.new('_method=DELETE')}
    Rack::Request.new(env).request_method.should.equal 'DELETE'

    env = {'REQUEST_METHOD' => 'POST', 'rack.input' => StringIO.new('_method=PUT')}
    Rack::Request.new(env).request_method.should.equal 'PUT'
  end
  
  it "should not allow faking" do
    env = {'REQUEST_METHOD' => 'POST', 'rack.input' => StringIO.new('_method=GET')}
    Rack::Request.new(env).request_method.should.equal 'POST'

    env = {'REQUEST_METHOD' => 'GET', 'rack.input' => StringIO.new('_method=POST')}
    Rack::Request.new(env).request_method.should.equal 'GET'
  end
end


