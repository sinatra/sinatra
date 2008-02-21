require File.dirname(__FILE__) + '/helper'

context "Sinatra" do
  
  setup do
    Sinatra.application = nil
  end
  
  specify "should handle result of nil" do
    get '/' do
      nil
    end
    
    get_it '/'
    should.be.ok
    body.should == ''
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
  
  specify "renders a body with a redirect" do
    Sinatra::EventContext.any_instance.expects(:foo).returns('blah')
    get "/" do
      redirect 'foo', :foo
    end
    get_it '/'
    should.be.redirection
    headers['Location'].should.equal 'foo'
    body.should.equal 'blah'
  end
  
  specify "body sets content and ends event" do
    
    Sinatra::EventContext.any_instance.expects(:foo).never
    
    get '/set_body' do
      stop 'Hello!'
      stop 'World!'
      foo
    end
    
    get_it '/set_body'
    
    should.be.ok
    body.should.equal 'Hello!'
    
  end
      
end
