require File.dirname(__FILE__) + '/../helper.rb'

describe "When a PrettyUrl is created" do
  it "should remember its raw path" do
    Sinatra::PrettyUrl.new('/foo/:bar').path.should.equal '/foo/:bar'
  end
  
  it "should match a uri with one to many params" do
    Sinatra::PrettyUrl.new('/foo').matches?('/foo').should.equal true
    Sinatra::PrettyUrl.new('/foo/:name.:format').matches?('/foo/blake2-test.xml').should.equal true
    Sinatra::PrettyUrl.new('/foo/:name.:format').matches?('/foo/blake2-test..xml').should.equal false
    Sinatra::PrettyUrl.new('/index').matches?('/foo').should.equal false
    Sinatra::PrettyUrl.new('/').matches?('/bar').should.equal false
  end
  
  it "should extract vars as params" do
    url = Sinatra::PrettyUrl.new('/foo/:name.:format')
    params = url.extract_params('/foo/blake2-test.xml')
    params.should.equal :format => "xml", :name => 'blake2-test'
  end
  
  it "should always add a format" do
    url = Sinatra::PrettyUrl.new('/foo/:name')
    params = url.extract_params('/foo/blake')
    params[:format].should.equal "html"
    params = url.extract_params('/foo/blake.xml')
    params[:format].should.equal "xml"
  end
  
  it "should default to html format if not a valid format" do
    url = Sinatra::PrettyUrl.new('/foo/:name')
    params = url.extract_params('/foo/blake.mizerany')
    params[:format].should.equal "html"
  end
  
end


