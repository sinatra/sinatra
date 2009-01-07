require 'test/spec'
require 'sinatra/base'
require 'sinatra/test'

describe "Builder Templates" do
  include Sinatra::Test

  def builder_app(&block)
    mock_app {
      set :views, File.dirname(__FILE__) + '/views'
      get '/', &block
    }
    get '/'
  end

  it 'renders inline Builder strings' do
    builder_app { builder 'xml.instruct!' }
    should.be.ok
    body.should.equal %{<?xml version="1.0" encoding="UTF-8"?>\n}
  end

  it 'renders inline blocks' do
    builder_app {
      @name = "Frank & Mary"
      builder do |xml|
        xml.couple @name
      end
    }
    should.be.ok
    body.should.equal "<couple>Frank &amp; Mary</couple>\n"
  end

  it 'renders .builder files in views path' do
    builder_app {
      @name = "Blue"
      builder :hello
    }
    should.be.ok
    body.should.equal %(<exclaim>You're my boy, Blue!</exclaim>\n)
  end

  it "renders with inline layouts" do
    mock_app {
      layout do
        %(xml.layout { xml << yield })
      end
      get('/') { builder %(xml.em 'Hello World') }
    }
    get '/'
    should.be.ok
    body.should.equal "<layout>\n<em>Hello World</em>\n</layout>\n"
  end

  it "renders with file layouts" do
    builder_app {
      builder %(xml.em 'Hello World'), :layout => :layout2
    }
    should.be.ok
    body.should.equal "<layout>\n<em>Hello World</em>\n</layout>\n"
  end

  it "raises error if template not found" do
    mock_app {
      get('/') { builder :no_such_template }
    }
    lambda { get('/') }.should.raise(Errno::ENOENT)
  end
end
