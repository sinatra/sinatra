require File.dirname(__FILE__) + '/helper'

context "Haml" do

  setup do
    Sinatra.application = nil
  end
  
  context "without layouts" do
    
    setup do
      Sinatra.application = nil
    end
    
    specify "should render" do
    
      get '/no_layout' do
        haml '== #{1+1}'
      end
    
      get_it '/no_layout'
      should.be.ok
      body.should == "2\n"

    end
  end
  
  context "with layouts" do

    setup do
      Sinatra.application = nil
    end
    
    specify "can be inline" do
    
      layout do
        '== This is #{@content}!'
      end
    
      get '/lay' do
        haml 'Blake'
      end
    
      get_it '/lay'
      should.be.ok
      body.should.equal "This is Blake\n!\n"

    end
  
    specify "can use named layouts" do
    
      layout :pretty do
        "%h1== \#{@content}"
      end
        
      get '/pretty' do
        haml 'Foo', :layout => :pretty
      end
    
      get '/not_pretty' do
        haml 'Bar'
      end
    
      get_it '/pretty'
      body.should.equal "<h1>Foo</h1>\n"
    
      get_it '/not_pretty'
      body.should.equal "Bar\n"
    
    end
  
    specify "can be read from a file if they're not inlined" do
    
      get '/foo' do
        @title = 'Welcome to the Hello Program'
        haml 'Blake', :layout => :foo_layout,
                      :views_directory => File.dirname(__FILE__) + "/views"
      end
    
      get_it '/foo'
      body.should.equal "Welcome to the Hello Program\nHi Blake\n"
    
    end

  end
  
  
end
