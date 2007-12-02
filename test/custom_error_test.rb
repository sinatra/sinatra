require File.dirname(__FILE__) + '/helper'

context "Custom Errors (in general)" do

  setup do
    Sinatra.application.options.raise_errors = false
  end
  
  teardown do
    Sinatra.application.options.raise_errors = true
  end

  specify "override the default 404" do
    
    get_it '/'
    should.be.not_found
    body.should.equal '<h1>Not Found</h1>'
    
    error 404 do
      'Custom 404'
    end
    
    get_it '/'
    should.be.not_found
    body.should.equal 'Custom 404'
    
  end
  
  specify "override the default 500" do
    
    get '/' do
      raise 'asdf'
    end
    
    get_it '/'
    status.should.equal 500
    body.should.equal '<h1>Internal Server Error</h1>'
    
    
    error 500 do
      'Custom 500 for ' + request.env['sinatra.error'].message
    end
    
    get_it '/'
    
    get_it '/'
    status.should.equal 500
    body.should.equal 'Custom 500 for asdf'
    
  end

end





