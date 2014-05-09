require 'spec_helper'

describe Sinatra::LinkHeader do
  before do
    mock_app do
      helpers Sinatra::LinkHeader
      before('/') { link 'something', :rel => 'from-filter', :foo => :bar }

      get '/' do
        link :something, 'booyah'
      end

      get '/style' do
        stylesheet '/style.css'
      end

      get '/prefetch' do
        prefetch '/foo'
      end

      get '/link_headers' do
        response['Link'] = "<foo>     ;bar=\"baz\""
        stylesheet '/style.css'
        prefetch '/foo'
        link_headers
      end
    end
  end

  describe :link do
    it "sets link headers" do
      get '/'
      headers['Link'].lines.should include('<booyah>; rel="something"')
    end

    it "returns link html tags" do
      get '/'
      body.should == '<link href="booyah" rel="something" />'
    end

    it "takes an options hash" do
      get '/'
      elements = ["<something>", "foo=\"bar\"", "rel=\"from-filter\""]
      headers['Link'].lines.first.strip.split('; ').sort.should == elements
    end
  end

  describe :stylesheet do
    it 'sets link headers' do
      get '/style'
      headers['Link'].should match(%r{^</style\.css>;})
    end

    it 'sets type to text/css' do
      get '/style'
      headers['Link'].should include('type="text/css"')
    end

    it 'sets rel to stylesheet' do
      get '/style'
      headers['Link'].should include('rel="stylesheet"')
    end

    it 'returns html tag' do
      get '/style'
      body.should match(%r{^<link href="/style\.css"})
    end
  end

  describe :prefetch do
    it 'sets link headers' do
      get '/prefetch'
      headers['Link'].should match(%r{^</foo>;})
    end

    it 'sets rel to prefetch' do
      get '/prefetch'
      headers['Link'].should include('rel="prefetch"')
    end

    it 'returns html tag' do
      get '/prefetch'
      body.should == '<link href="/foo" rel="prefetch" />'
    end
  end

  describe :link_headers do
    it 'generates html for all link headers' do
      get '/link_headers'
      body.should include('<link href="/foo" rel="prefetch" />')
      body.should include('<link href="/style.css" ')
    end

    it "respects Link headers not generated on its own" do
      get '/link_headers'
      body.should include('<link href="foo" bar="baz" />')
    end
  end
end
