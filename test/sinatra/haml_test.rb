require File.dirname(__FILE__) + '/../helper'


context "Haml" do

  before(:each) do
    Sinatra::Event.before_filters.clear
    Sinatra::Event.after_filters.clear
    Sinatra::EventManager.reset!
  end

  after(:each) do
    Sinatra::Event.before_filters.clear
    Sinatra::Event.after_filters.clear
    Sinatra::EventManager.reset!
  end
  
  specify "does layouts" do
    layout do
      '%h1== Hello #{yield}'
    end

    get "/" do
      haml 'Ben'
    end
    
    get_it '/'
    
    body.should.equal "<h1>Hello Ben</h1>\n"
  end
  
end

