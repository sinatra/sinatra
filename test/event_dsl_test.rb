require File.dirname(__FILE__) + '/helper'

context "Event's DSL" do
  
  specify "Takes multiple routes" do
    
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
  
end
