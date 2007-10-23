require File.dirname(__FILE__) + '/../helper'
require 'stringio'

context "StaticEvent" do
  
  before(:each) do
    Sinatra::EventManager.reset!
  end
  
  specify "recognizes paths prefixed with it's path" do
    File.expects(:exists?).with('/x/bar/test.jpg').returns(true)
    File.expects(:file?).with('/x/bar/test.jpg').returns(true)
    Sinatra::StaticEvent.new('/foo', '/x/bar').recognize('/foo/test.jpg').should.equal true
    
    File.expects(:exists?).with('/x/bar/test.jpg').returns(false)
    Sinatra::StaticEvent.new('/foo', '/x/bar').recognize('/foo/test.jpg').should.equal false
  end

  specify "sets headers for file type" do
    File.expects(:open).with('/x/bar/test.jpg', 'rb').returns(StringIO.new)
    File.expects(:size).with('/x/bar/test.jpg').returns(255)
    result = Sinatra::StaticEvent.new('/foo', '/x/bar').attend(stub(:path_info => '/foo/test.jpg'))
    result.headers.should.equal 'Content-Type' => 'image/jpeg', 'Content-Length' => '255'
    result.body.each { }
  end
  
  specify "makes sure it is a file and not a directory" do
    File.expects(:exists?).with('/x/bar').returns(true)
    File.expects(:file?).with('/x/bar').returns(false)
    Sinatra::StaticEvent.new('/foo', '/x').recognize('/foo/bar').should.equal false
  end
  
end

context "StaticEvent (In full context)" do
  
  specify "should serve a static file" do
    e = static '/x', root = File.dirname(__FILE__) + '/static_files'
    
    File.read(e.physical_path_for('/x/foo.txt')).should.equal 'You found foo!'
  
    get_it '/x/foo.txt'
  
    status.should.equal 200
    body.should.equal 'You found foo!'
  end
  
end