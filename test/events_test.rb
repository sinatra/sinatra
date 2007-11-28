require File.dirname(__FILE__) + '/../lib/sinatra'

require 'rubygems'
require 'test/spec'

context "Simple Events" do

  specify "return what's at the end" do
    
    application = Sinatra::Application.new
    
    route = application.define_event(:get, '/') do
      'Hello'
    end
        
    result = application.lookup(:get, '/')
    
    result.should.equal route
  end
    
end
