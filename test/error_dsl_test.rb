require File.dirname(__FILE__) + '/helper'

context "Defining Errors" do

  setup do
    Sinatra.routes.clear
    Sinatra.setup_default_events!
  end
  
  specify "should raise error if no block given" do
    
    lambda { error 404 }.should.raise(RuntimeError)
    lambda { error(404) {} }.should.not.raise
    
  end
  
  specify "should auto-set status for error events" do
    error 404 do
      'custom 404'
    end
    
    get_it '/'
    
    should.be.not_found
  end
  
  xspecify "should handle multiple errors" do
    
    get 404, 500 do
      'multi custom error'
    end
    
    get '/error' do
      raise 'asdf'
    end
    
    get_it '/'
    
  end
  
end
