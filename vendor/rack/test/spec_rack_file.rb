require 'test/spec'

require 'rack/file'
require 'rack/lint'

require 'rack/mock'

context "Rack::File" do
  DOCROOT = File.expand_path(File.dirname(__FILE__))

  specify "serves files" do
    res = Rack::MockRequest.new(Rack::Lint.new(Rack::File.new(DOCROOT))).
      get("/cgi/test")

    res.should.be.ok
    res.should =~ /ruby/
  end
  
  specify "serves files with URL encoded filenames" do
    res = Rack::MockRequest.new(Rack::Lint.new(Rack::File.new(DOCROOT))).
      get("/cgi/%74%65%73%74") # "/cgi/test"

    res.should.be.ok
    res.should =~ /ruby/
  end

  specify "does not allow directory traversal" do
    res = Rack::MockRequest.new(Rack::Lint.new(Rack::File.new(DOCROOT))).
      get("/cgi/../test")

    res.should.be.forbidden
  end

  specify "404s if it can't find the file" do
    res = Rack::MockRequest.new(Rack::Lint.new(Rack::File.new(DOCROOT))).
      get("/cgi/blubb")

    res.should.be.not_found
  end
end
