require File.dirname(__FILE__) + '/helper'

context "Static files (by default)" do

  specify "are served from root/public" do
    Sinatra.application.options.public = File.dirname(__FILE__) + '/public'
    get_it '/foo.xml'
    should.be.ok
    body.should.equal "<foo></foo>\n"
  end

end

