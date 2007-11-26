require File.dirname(__FILE__) + '/helper'

context "Defining Errors" do

  setup do
    Sinatra.reset!
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
  
  specify "should handle multiple errors" do
    
    error 404, 500 do
      'multi custom error'
    end
    
    get '/error' do
      raise 'asdf'
    end
    
    dont_raise_errors do
      get_it '/error'
    end
    
    status.should.equal 500
    body.should.equal 'multi custom error'
    
    get_it '/'
    status.should.equal 404
    
    body.should.equal 'multi custom error'
    
  end
  
end
