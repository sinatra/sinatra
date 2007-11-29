require File.dirname(__FILE__) + '/helper'

context "Layouts (in general)" do
  
  setup do
    Sinatra.application = nil
  end
  
  specify "can be inline" do
    
    layout do
      %Q{This is #{@content}!}
    end
    
    get '/lay' do
      render 'Blake'
    end
    
    get_it '/lay'
    should.be.ok
    body.should.equal 'This is Blake!'

  end
  
  specify "can use named layouts" do
    
    layout :pretty do
      %Q{<h1>#{@content}</h1>}
    end
        
    get '/pretty' do
      render 'Foo', :layout => :pretty
    end
    
    get '/not_pretty' do
      render 'Bar'
    end
    
    get_it '/pretty'
    body.should.equal '<h1>Foo</h1>'
    
    get_it '/not_pretty'
    body.should.equal 'Bar'
    
  end
  
end
