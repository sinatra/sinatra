require File.dirname(__FILE__) + '/helper'

context "Dispatching" do
    
  specify "should return the correct block" do
    Sinatra.routes[:get] << r = Sinatra::Route.new('/') do
      'main'
    end
            
    result = Sinatra.determine_event(:get, '/')
    result.block.should.be r.block
  end
  
end
