require File.dirname(__FILE__) + '/../helper'

describe "When a dispatcher receives a request" do  
      
  it "should attend to the event" do
    
    Sinatra::Event.new(:get, '/') do
      body 'this is the index as a get'
    end
    
    get_it "/"
        
    status.should.equal 200
    text.should.equal 'this is the index as a get'
    headers['Content-Type'].should.equal 'text/html'
    
    post_it "/test"
        
    status.should.equal 404
    text.scan("Not Found :: Sinatra").size.should.equal 1
    headers['Content-Type'].should.equal 'text/html'
    
    get_it '/foo'
    
    status.should.equal 404
    text.scan("Not Found :: Sinatra").size.should.equal 1
    
  end
    
end