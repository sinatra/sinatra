require File.dirname(__FILE__) + '/helper'

context "Erb" do

  setup do
    Sinatra.application = nil
  end
  
  context "without layouts" do
    
    setup do
      Sinatra.application = nil
    end
    
    specify "should render" do
    
      get '/no_layout' do
        erb '<%= 1 + 1 %>'
      end
    
      get_it '/no_layout'
      should.be.ok
      body.should == '2'

    end
  end
  
  context "with layouts" do

    setup do
      Sinatra.application = nil
    end
    
    specify "can be inline" do
    
      layout do
        %Q{This is <%= @content %>!}
      end
    
      get '/lay' do
        erb 'Blake'
      end
    
      get_it '/lay'
      should.be.ok
      body.should.equal 'This is Blake!'

    end
  
    specify "can use named layouts" do
    
      layout :pretty do
        %Q{<h1><%= @content %></h1>}
      end
        
      get '/pretty' do
        erb 'Foo', :layout => :pretty
      end
    
      get '/not_pretty' do
        erb 'Bar'
      end
    
      get_it '/pretty'
      body.should.equal '<h1>Foo</h1>'
    
      get_it '/not_pretty'
      body.should.equal 'Bar'
    
    end
  
    specify "can be read from a file if they're not inlined" do
    
      get '/foo' do
        @title = 'Welcome to the Hello Program'
        erb 'Blake', :layout => :foo_layout,
                     :views_directory => File.dirname(__FILE__) + "/views"
      end
    
      get_it '/foo'
      body.should.equal "Welcome to the Hello Program\nHi Blake\n"
    
    end

  end
  
  
end
