require File.dirname(__FILE__) + '/helper'

context "Event's DSL" do
  
  specify "Takes multiple routes" do
    
    get '/', '/foo' do
      'hello from me'
    end
    
    get_it '/'
    body.should.equal 'hello from me'
    
    get_it '/foo'
    body.should.equal 'hello from me'
    
  end
  
end
