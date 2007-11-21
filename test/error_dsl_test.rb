require File.dirname(__FILE__) + '/helper'

context "Defining Errors" do
  
  specify "should raise error if no block given" do
    
    lambda { error 404 }.should.raise(RuntimeError)
    lambda { error(404) {} }.should.not.raise
    
  end
  
end
