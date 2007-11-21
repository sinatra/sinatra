require File.dirname(__FILE__) + '/helper'



context "Dispatching" do
    
  include Sinatra::Test::Methods
    
  setup do
    Sinatra.routes.clear
  end
    
  specify "should return the correct block" do
    Sinatra.routes[:get] << r = Sinatra::Route.new('/') do
      'main'
    end
            
    result = Sinatra.determine_route(:get, '/')
    result.block.should.be r.block
  end
  
  specify "should return custom 404" do
    Sinatra.routes[404] = r = Proc.new { 'custom 404' }
    result = Sinatra.determine_route(:get, '/')
    result.should.be r
  end
  
  specify "should give custom 500 if error when called" do
    Sinatra.routes[500] = r = Proc.new { 'custom 500' }

    Sinatra.routes[:get] << Sinatra::Route.new('/') do
      raise 'asdf'
    end
    
    get_it '/'

    body.should.equal 'custom 500'
  end
  
  specify "should give standard 500 if error when called" do
    Sinatra.routes[:get] << Sinatra::Route.new('/') do
      raise 'asdf'
    end
    
    get_it '/'

    body.should.match /^asdf/
  end
  
end
