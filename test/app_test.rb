require File.dirname(__FILE__) + '/helper'

context "Sinatra" do
  
  setup do
    Sinatra.application = nil
  end
  
  specify "handles events" do
    get '/:name' do
      'Hello ' + params[:name]
    end
    
    get_it '/Blake'
    
    should.be.ok
    body.should.equal 'Hello Blake'
  end
  
  specify "follows redirects" do
    get '/' do
      redirect '/blake'
    end
    
    get '/blake' do
      'Mizerany'
    end
    
    get_it '/'
    should.be.redirection
    body.should.equal ''
    
    follow!
    should.be.ok
    body.should.equal 'Mizerany'
  end
  
  specify "body sets content and ends event" do
    
    Sinatra::EventContext.any_instance.expects(:foo).never
    
    get '/set_body' do
      body 'Hello!'
      body 'Not this'
      foo
    end
    
    get_it '/set_body'
    
    should.be.ok
    body.should.equal 'Hello!'
    
  end
      
end
