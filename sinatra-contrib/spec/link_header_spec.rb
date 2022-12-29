require 'spec_helper'

RSpec.describe Sinatra::LinkHeader do
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
      expect(headers['Link']).to include('<booyah>; rel="something"')
    end

    it "returns link html tags" do
      get '/'
      expect(body).to eq('<link href="booyah" rel="something" />')
    end

    it "takes an options hash" do
      get '/'
      elements = ["<something>", "foo=\"bar\"", "rel=\"from-filter\""]
      expect(headers['Link'].split(",").first.strip.split('; ').sort).to eq(elements)
    end
  end

  describe :stylesheet do
    it 'sets link headers' do
      get '/style'
      expect(headers['Link']).to match(%r{^</style\.css>;})
    end

    it 'sets type to text/css' do
      get '/style'
      expect(headers['Link']).to include('type="text/css"')
    end

    it 'sets rel to stylesheet' do
      get '/style'
      expect(headers['Link']).to include('rel="stylesheet"')
    end

    it 'returns html tag' do
      get '/style'
      expect(body).to match(%r{^<link href="/style\.css"})
    end
  end

  describe :prefetch do
    it 'sets link headers' do
      get '/prefetch'
      expect(headers['Link']).to match(%r{^</foo>;})
    end

    it 'sets rel to prefetch' do
      get '/prefetch'
      expect(headers['Link']).to include('rel="prefetch"')
    end

    it 'returns html tag' do
      get '/prefetch'
      expect(body).to eq('<link href="/foo" rel="prefetch" />')
    end
  end

  describe :link_headers do
    it 'generates html for all link headers' do
      get '/link_headers'
      expect(body).to include('<link href="/foo" rel="prefetch" />')
      expect(body).to include('<link href="/style.css" ')
    end

    it "respects Link headers not generated on its own" do
      get '/link_headers'
      expect(body).to include('<link href="foo" bar="baz" />')
    end
  end
end
