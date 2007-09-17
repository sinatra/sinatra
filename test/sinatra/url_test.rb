require File.dirname(__FILE__) + '/../helper'

describe "Route" do
  it "should recognize params in urls" do
    route = Sinatra::Route.new('/foo/:test/:blake')

    route.recognize('/foo/bar/baz').should.equal true
    route.params.should.equal :test => 'bar', :blake => 'baz', :format => 'html'

    route.recognize('/foo/bar/baz.xml').should.equal true
    route.params.should.equal :test => 'bar', :blake => 'baz', :format => 'xml'
  end
  
  # it "test" do
  #   p /^(\w)$|^(\w\.\w)$/.match('b').captures rescue 'NOTHING'
  # end
end

