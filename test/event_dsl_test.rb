require File.dirname(__FILE__) + '/helper'

context "Event's DSL" do
  
  setup do
    Sinatra.reset!
  end
  
  specify "takes multiple routes" do
    
    get '/', '/foo' do
      'hello from me'
    end
    
    get_it '/'
    should.be.ok
    body.should.equal 'hello from me'
    
    get_it '/foo'
    should.be.ok
    body.should.equal 'hello from me'
    
  end
  
  specify "should be able to halt from within request" do
    
    get '/halting' do
      throw :halt, 'halted'
      'not this'
    end
    
    get_it '/halting'
    
    should.be.ok
    body.should.equal 'halted'
    
  end
  
end
