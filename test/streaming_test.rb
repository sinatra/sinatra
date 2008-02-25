require File.dirname(__FILE__) + '/helper'

context "Static files (by default)" do

  specify "are served from root/public" do
    Sinatra.application.options.public = File.dirname(__FILE__) + '/public'
    get_it '/foo.xml'
    should.be.ok
    headers['Content-Length'].should.equal '12'
    headers['Content-Type'].should.equal 'application/xml'
    body.should.equal "<foo></foo>\n"
  end
  
end

context "SendData" do
  
  setup do
    Sinatra.application = nil
  end

  specify "should send the data with options" do
    get '/' do
      send_data 'asdf', :status => 500
    end
  
    get_it '/'
  
    should.be.server_error
    body.should.equal 'asdf'
  end
  
end
