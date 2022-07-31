# frozen_string_literal: true

RSpec.describe Rack::Protection::HttpOrigin do
  it_behaves_like 'any rack application'

  before(:each) do
    mock_app do
      use Rack::Protection::HttpOrigin
      run DummyApp
    end
  end

  %w[GET HEAD POST PUT DELETE].each do |method|
    it "accepts #{method} requests with no Origin" do
      expect(send(method.downcase, '/')).to be_ok
    end
  end

  %w[GET HEAD].each do |method|
    it "accepts #{method} requests with non-permitted Origin" do
      expect(send(method.downcase, '/', {}, 'HTTP_ORIGIN' => 'http://malicious.com')).to be_ok
    end
  end

  %w[GET HEAD POST PUT DELETE].each do |method|
    it "accepts #{method} requests when allow_if is true" do
      mock_app do
        use Rack::Protection::HttpOrigin, allow_if: ->(env) { env.key?('HTTP_ORIGIN') }
        run DummyApp
      end
      expect(send(method.downcase, '/', {}, 'HTTP_ORIGIN' => 'http://any.domain.com')).to be_ok
    end
  end

  %w[POST PUT DELETE].each do |method|
    it "denies #{method} requests with non-permitted Origin" do
      expect(send(method.downcase, '/', {}, 'HTTP_ORIGIN' => 'http://malicious.com')).not_to be_ok
    end

    it "accepts #{method} requests with permitted Origin" do
      mock_app do
        use Rack::Protection::HttpOrigin, permitted_origins: ['http://www.friend.com']
        run DummyApp
      end
      expect(send(method.downcase, '/', {}, 'HTTP_ORIGIN' => 'http://www.friend.com')).to be_ok
    end
  end
end
