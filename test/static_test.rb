require File.dirname(__FILE__) + '/helper'

context "Static" do
  
  setup do
    Sinatra.reset!
    Sinatra.config[:root] = File.dirname(__FILE__)
  end
  
  specify "sends files" do
    
    get_it '/foo.xml'
    
    should.be.ok
    body.should.equal '<foo></foo>'
    headers.should.equal 'Content-Type' => 'application/xml',
                         'Content-Length' => '<foo></foo>'.size
    
  end
  
  specify "defaults to text/plain" do
    
    get_it '/foo.foo'
    
    should.be.ok
    body.should.equal 'bar'
    headers.should.equal 'Content-Type' => 'text/plain',
                         'Content-Length' => 'bar'.size
  end
  
  specify "default to user definied type" do
    Sinatra.config[:default_static_mime_type] = 'foo/bar'
    
    get_it '/foo.foo'
    
    should.be.ok
    body.should.equal 'bar'
    headers.should.equal 'Content-Type' => 'foo/bar',
                         'Content-Length' => 'bar'.size
  end
  
  specify "handles files without ext" do
    get_it '/xyz'
    
    should.be.ok
    body.should.equal 'abc'
    headers.should.equal 'Content-Type' => 'text/plain',
                         'Content-Length' => 'bar'.size
  end
  
  specify "should handle javascript correctly" do
    
    get_it '/test.js'
      
    should.be.ok
    body.should.equal 'var i = 11;'
    headers.should.equal 'Content-Type' => 'text/javascript',
                         'Content-Length' => 'var i = 11;'.size
    
  end
  
end
