# frozen_string_literal: true

RSpec.describe Rack::Protection::JsonCsrf do
  it_behaves_like 'any rack application'

  module DummyAppWithBody
    module Closeable
      def close
        @closed = true
      end

      def closed?
        @closed
      end
    end

    def self.body
      @body ||= begin
        body = ['ok']
        body.extend(Closeable)
        body
      end
    end

    def self.call(env)
      Thread.current[:last_env] = env

      if Rack::RELEASE >= '3.0'
        headers = { 'content-type' => 'application/json' }
      else
        headers = { 'Content-Type' => 'application/json' }
      end

      [200, headers, body]
    end
  end

  describe 'json response' do
    before do
      if Rack::RELEASE >= '3.0'
        headers = { 'content-type' => 'application/json' }
      else
        headers = { 'Content-Type' => 'application/json' }
      end

      mock_app { |_e| [200, headers, []] }
    end

    it 'denies get requests with json responses with a remote referrer' do
      expect(get('/', {}, 'HTTP_REFERER' => 'http://evil.com')).not_to be_ok
    end

    it 'closes the body returned by the app if it denies the get request' do
      mock_app DummyAppWithBody do |_e|
        if Rack::RELEASE >= '3.0'
          headers = { 'content-type' => 'application/json' }
        else
          headers = { 'Content-Type' => 'application/json' }
        end

        [200, headers, []]
      end

      get('/', {}, 'HTTP_REFERER' => 'http://evil.com')

      expect(DummyAppWithBody.body).to be_closed
    end

    it 'accepts requests with json responses with a remote referrer when allow_if is true' do
      mock_app do
        use Rack::Protection::JsonCsrf, allow_if: ->(env) { env['HTTP_REFERER'] == 'http://good.com' }

        if Rack::RELEASE >= '3.0'
          headers = { 'content-type' => 'application/json' }
        else
          headers = { 'Content-Type' => 'application/json' }
        end

        run proc { |_e| [200, headers, []] }
      end

      expect(get('/', {}, 'HTTP_REFERER' => 'http://good.com')).to be_ok
    end

    it "accepts requests with json responses with a remote referrer when there's an origin header set" do
      expect(get('/', {}, 'HTTP_REFERER' => 'http://good.com', 'HTTP_ORIGIN' => 'http://good.com')).to be_ok
    end

    it "accepts requests with json responses with a remote referrer when there's an x-origin header set" do
      expect(get('/', {}, 'HTTP_REFERER' => 'http://good.com', 'HTTP_X_ORIGIN' => 'http://good.com')).to be_ok
    end

    it 'accepts get requests with json responses with a local referrer' do
      expect(get('/', {}, 'HTTP_REFERER' => '/')).to be_ok
    end

    it 'accepts get requests with json responses with no referrer' do
      expect(get('/', {})).to be_ok
    end

    it 'accepts XHR requests' do
      expect(get('/', {}, 'HTTP_REFERER' => 'http://evil.com', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest')).to be_ok
    end
  end

  describe 'not json response' do
    it 'accepts get requests with 304 headers' do
      mock_app { |_e| [304, {}, []] }
      expect(get('/', {}).status).to eq(304)
    end
  end

  describe 'with drop_session as default reaction' do
    it 'still denies' do
      mock_app do
        use Rack::Protection, reaction: :drop_session

        if Rack::RELEASE >= '3.0'
          headers = { 'content-type' => 'application/json' }
        else
          headers = { 'Content-Type' => 'application/json' }
        end

        run proc { |_e| [200, headers, []] }
      end

      session = { foo: :bar }
      get('/', {}, 'HTTP_REFERER' => 'http://evil.com', 'rack.session' => session)
      expect(last_response).not_to be_ok
    end
  end
end
