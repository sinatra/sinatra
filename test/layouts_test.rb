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
  
end
