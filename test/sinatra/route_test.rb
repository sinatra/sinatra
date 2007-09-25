require File.dirname(__FILE__) + '/../helper'

describe "Route" do
  it "gives :format for free" do
    route = Sinatra::Route.new('/foo/:test/:blake')

    route.recognize('/foo/bar/baz').should.equal true
    route.params.should.equal :test => 'bar', :blake => 'baz', :format => 'html'

    route.recognize('/foo/bar/baz.xml').should.equal true
    route.params.should.equal :test => 'bar', :blake => 'baz', :format => 'xml'
  end
  
  it "doesn't auto add :format for routes with explicit formats" do
    route = Sinatra::Route.new('/foo/:test.xml')
    route.recognize('/foo/bar').should.equal false
    route.recognize('/foo/bar.xml').should.equal true
    route.params.should.equal :test => 'bar', :format => 'xml'
  end
end

