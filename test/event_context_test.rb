require File.dirname(__FILE__) + '/helper'

context "EventContext" do

  specify "DSLified setters" do

    cx = Sinatra::EventContext.new(stub_everything, Rack::Response.new, {})
    lambda {
      cx.status 404
    }.should.not.raise(ArgumentError)

  end

end

