# frozen_string_literal: true

RSpec.describe Rack::Protection::CookieTossing do
  it_behaves_like 'any rack application'

  context 'with default reaction' do
    before(:each) do
      mock_app do
        use Rack::Protection::CookieTossing
        run DummyApp
      end
    end

    it 'accepts requests with a single session cookie' do
      get '/', {}, 'HTTP_COOKIE' => 'rack.session=SESSION_TOKEN'
      expect(last_response).to be_ok
    end

    it 'denies requests with duplicate session cookies' do
      get '/', {}, 'HTTP_COOKIE' => 'rack.session=EVIL_SESSION_TOKEN; rack.session=SESSION_TOKEN'
      expect(last_response).not_to be_ok
    end

    it 'denies requests with sneaky encoded session cookies' do
      get '/', {}, 'HTTP_COOKIE' => 'rack.session=EVIL_SESSION_TOKEN; rack.%73ession=SESSION_TOKEN'
      expect(last_response).not_to be_ok
    end

    it 'adds the correct Set-Cookie header' do
      get '/some/path', {}, 'HTTP_COOKIE' => 'rack.%73ession=EVIL_SESSION_TOKEN; rack.session=EVIL_SESSION_TOKEN; rack.session=SESSION_TOKEN'

      # Rack no longer URI encodes the % in the cookie in Rack 3.1+
      # https://github.com/sinatra/sinatra/issues/2017
      cookie_key = if Rack::RELEASE < "3.1"
        "rack.%2573ession"
      else
        "rack.%73ession"
      end

      expected_header = <<-END.chomp.split("\n")
#{cookie_key}=; domain=example.org; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT
#{cookie_key}=; domain=example.org; path=/some; expires=Thu, 01 Jan 1970 00:00:00 GMT
#{cookie_key}=; domain=example.org; path=/some/path; expires=Thu, 01 Jan 1970 00:00:00 GMT
rack.session=; domain=example.org; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT
rack.session=; domain=example.org; path=/some; expires=Thu, 01 Jan 1970 00:00:00 GMT
rack.session=; domain=example.org; path=/some/path; expires=Thu, 01 Jan 1970 00:00:00 GMT
      END
      expect(last_response.headers['Set-Cookie']).to eq(expected_header)
    end
  end

  context 'with redirect reaction' do
    before(:each) do
      mock_app do
        use Rack::Protection::CookieTossing, reaction: :redirect
        run DummyApp
      end
    end

    it 'redirects requests with duplicate session cookies' do
      get '/', {}, 'HTTP_COOKIE' => 'rack.session=EVIL_SESSION_TOKEN; rack.session=SESSION_TOKEN'
      expect(last_response).to be_redirect
      expect(last_response.location).to eq('/')
    end

    it 'redirects requests with sneaky encoded session cookies' do
      get '/path', {}, 'HTTP_COOKIE' => 'rack.%73ession=EVIL_SESSION_TOKEN; rack.session=SESSION_TOKEN'
      expect(last_response).to be_redirect
      expect(last_response.location).to eq('/path')
    end
  end

  context 'with custom session key' do
    it 'denies requests with duplicate session cookies' do
      mock_app do
        use Rack::Protection::CookieTossing, session_key: '_session'
        run DummyApp
      end

      get '/', {}, 'HTTP_COOKIE' => '_session=EVIL_SESSION_TOKEN; _session=SESSION_TOKEN'
      expect(last_response).not_to be_ok
    end
  end
end
