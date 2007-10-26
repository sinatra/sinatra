require File.dirname(__FILE__) + '/../helper'


context "Haml" do

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

