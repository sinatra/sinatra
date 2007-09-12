require File.dirname(__FILE__) + '/../../../test/helper'

context "A responder, by default" do
  specify "should default to html" do
    path = '/foo/test.xml'
    context = Sinatra::EventContext.new(stub(:params => { :format => 'xml' }))
    context.expects(:foo)
    context.instance_eval do
      format.xml { foo }
      format.html { bar }
    end
  end
end
