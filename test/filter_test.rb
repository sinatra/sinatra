require File.dirname(__FILE__) + '/helper'

class CustomResult
  
  def to_result(cx, *args)
    cx.status 404
    cx.body "Can't find this shit!"
  end
  
end

context "Filters" do
  
  setup do
    Sinatra.reset!
  end

  specify "halts when told" do
  
    before do
      throw :halt, 'fubar'
    end
  
    get '/' do
      'not this'
    end
    
    get_it '/'
    
    should.be.ok
    body.should.equal 'fubar'
    
  end
  
  specify "halts with status" do
    
    before do
      throw :halt, [401, 'get out dude!']
    end
    
    get '/auth' do
      "you're in!"
    end
    
    get_it '/auth'
    
    status.should.equal 401
    body.should.equal 'get out dude!'
    
  end
  
  specify "halts with custom result" do
    
    before do
      throw :halt, CustomResult.new
    end
    
    get '/custom' do
      'not this'
    end
    
    get_it '/custom'
    
    should.be.not_found
    body.should.equal "Can't find this shit!"
    
  end
  
end

context "Filter grouping" do
  
  setup do
    Sinatra.reset!
  end

  specify "befores only run for groups if specified" do

    Sinatra::EventContext.any_instance.expects(:foo).times(4)
    
    before do
      foo  # this should be called before all events
    end
    
    after do
      foo
    end
    
    before :admins do
      throw :halt, 'not authorized'
    end
    
    get '/', :groups => :admins do
      'asdf'
    end
    
    get '/foo' do
      'yeah!'
    end
            
    get_it '/'
  
    should.be.ok
    body.should.equal 'not authorized'
    
    get_it '/foo'
    
    should.be.ok
    body.should.equal 'yeah!'

  end
  
end