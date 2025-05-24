# frozen_string_literal: true

require 'stringio'

RSpec.describe Rack::Protection::HostAuthorization do
  it_behaves_like 'any rack application'

  def assert_response(outcome:, headers:, last_response:)
    fail_message = "Expected outcome '#{outcome}' for headers '#{headers}' " \
                   "last_response.status '#{last_response.status}'"

    case outcome
    when :allowed
      expect(last_response).to be_ok, fail_message
    when :stopped
      expect(last_response.status).to eq(403), fail_message
      expect(last_response.body).to eq('Host not permitted'), fail_message
    end
  end

  # we always specify HTTP_HOST because when HTTP_HOST is not set in env,
  # requests are made with env { HTTP_HOST => Rack::Test::DEFAULT_HOST }

  describe 'when subdomains under .test and .example.com are permitted' do
    requests = lambda do
      [
        { 'HTTP_HOST' => 'foo.test' },
        { 'HTTP_HOST' => 'example.com' },
        { 'HTTP_HOST' => 'foo.example.com' },
        { 'HTTP_HOST' => 'foo.bar.example.com' },
        { 'HTTP_HOST' => 'foo.test', 'HTTP_X_FORWARDED_HOST' => 'bar.baz.example.com' },
        { 'HTTP_HOST' => 'foo.test', 'HTTP_X_FORWARDED_HOST' => 'bar.test, baz.test' },
        { 'HTTP_HOST' => 'foo.test', 'HTTP_FORWARDED' => %(host="baz.test") },
        { 'HTTP_HOST' => 'foo.test', 'HTTP_FORWARDED' => %(host="baz.test" host="baz.example.com") }
      ]
    end

    requests.call.each do |headers|
      it "allows the request with headers '#{headers}'" do
        permitted_hosts = ['.test', '.example.com']
        mock_app do
          use Rack::Protection::HostAuthorization, permitted_hosts: permitted_hosts
          run DummyApp
        end

        get('/', {}, headers)
        assert_response(outcome: :allowed, headers: headers, last_response: last_response)
      end
    end
  end

  describe "when hosts under 'allowed.org' are permitted" do
    bad_requests = lambda do
      [
        { 'HTTP_HOST' => '.allowed.org' },
        { 'HTTP_HOST' => 'attacker.com#x.allowed.org' }
      ]
    end

    bad_requests.call.each do |headers|
      it "stops the request with headers '#{headers}'" do
        permitted_hosts = ['.allowed.org']
        mock_app do
          use Rack::Protection::HostAuthorization, permitted_hosts: permitted_hosts
          run DummyApp
        end

        get('/', {}, headers)
        assert_response(outcome: :stopped, headers: headers, last_response: last_response)
      end
    end
  end

  describe 'requests with bogus values in headers' do
    requests = lambda do |allowed_host|
      [
        { 'HTTP_HOST' => '::1' },
        { 'HTTP_HOST' => '[0]' },
        { 'HTTP_HOST' => allowed_host, 'HTTP_X_FORWARDED_HOST' => '[0]' },
        { 'HTTP_HOST' => allowed_host, 'HTTP_FORWARDED' => 'host=::1' },
        { 'HTTP_HOST' => allowed_host, 'HTTP_FORWARDED' => 'host=[0]' },
        { 'HTTP_HOST' => allowed_host, 'HTTP_FORWARDED' => 'host="::1"' },
        { 'HTTP_HOST' => allowed_host, 'HTTP_FORWARDED' => 'host="[0]"' }
      ]
    end

    requests.call('allowed.org').each do |headers|
      it "stops the request with headers '#{headers}'" do
        permitted_hosts = [IPAddr.new('0.0.0.0/0'), IPAddr.new('::/0'), 'allowed.org']
        mock_app(nil, lint: false) do
          use Rack::Protection::HostAuthorization, permitted_hosts: permitted_hosts
          run DummyApp
        end

        get('/', {}, headers)
        assert_response(outcome: :stopped, headers: headers, last_response: last_response)
      end
    end
  end

  describe 'when permitted hosts include IPAddr instance for 0.0.0.0/0' do
    good_requests = lambda do
      [
        { 'HTTP_HOST' => '127.0.0.1' },
        { 'HTTP_HOST' => '127.0.0.1:3000' },
        { 'HTTP_HOST' => '127.0.0.1', 'HTTP_X_FORWARDED_HOST' => '127.0.0.1' },
        { 'HTTP_HOST' => '127.0.0.1:3000', 'HTTP_X_FORWARDED_HOST' => '127.0.0.1:3000' },
        { 'HTTP_HOST' => '127.0.0.1', 'HTTP_X_FORWARDED_HOST' => 'example.com, 127.0.0.1' },
        { 'HTTP_HOST' => '127.0.0.1:3000', 'HTTP_X_FORWARDED_HOST' => 'example.com, 127.0.0.1:3000' },
        { 'HTTP_HOST' => '127.0.0.1', 'HTTP_FORWARDED' => 'host=127.0.0.1' },
        { 'HTTP_HOST' => '127.0.0.1', 'HTTP_FORWARDED' => 'host=example.com; host=127.0.0.1' },
        { 'HTTP_HOST' => '127.0.0.1:3000', 'HTTP_FORWARDED' => 'host=example.com; host=127.0.0.1:3000' }
      ]
    end

    good_requests.call.each do |headers|
      it "allows the request with headers '#{headers}'" do
        permitted_hosts = [IPAddr.new('0.0.0.0/0')]
        mock_app do
          use Rack::Protection::HostAuthorization, permitted_hosts: permitted_hosts
          run DummyApp
        end

        get('/', {}, headers)

        assert_response(outcome: :allowed, headers: headers, last_response: last_response)
      end
    end
  end

  describe 'when permitted hosts include IPAddr instance for ::/0' do
    good_requests = lambda do
      [
        { 'HTTP_HOST' => '[::1]' },
        { 'HTTP_HOST' => '[::1]:3000' },
        { 'HTTP_HOST' => '[::1]', 'HTTP_X_FORWARDED_HOST' => '::1' },
        { 'HTTP_HOST' => '[::1]', 'HTTP_X_FORWARDED_HOST' => '[::1]' },
        { 'HTTP_HOST' => '[::1]:3000', 'HTTP_X_FORWARDED_HOST' => '[::1]:3000' },
        { 'HTTP_HOST' => '[::1]', 'HTTP_X_FORWARDED_HOST' => 'example.com, [::1]' },
        { 'HTTP_HOST' => '[::1]:3000', 'HTTP_X_FORWARDED_HOST' => 'example.com, [::1]:3000' },
        { 'HTTP_HOST' => '[::1]', 'HTTP_FORWARDED' => 'host=[::1]' },
        { 'HTTP_HOST' => '[::1]', 'HTTP_FORWARDED' => 'host=example.com; host=[::1]' },
        { 'HTTP_HOST' => '[::1]:3000', 'HTTP_FORWARDED' => 'host=example.com; host=[::1]:3000' }
      ]
    end

    good_requests.call.each do |headers|
      it "allows the request with headers '#{headers}'" do
        permitted_hosts = [IPAddr.new('::/0')]
        mock_app do
          use Rack::Protection::HostAuthorization, permitted_hosts: permitted_hosts
          run DummyApp
        end

        get('/', {}, headers)

        assert_response(outcome: :allowed, headers: headers, last_response: last_response)
      end
    end
  end

  describe 'when permitted hosts include IPAddr instance for 192.168.0.1/32' do
    bad_requests = lambda do
      [
        { 'HTTP_HOST' => '127.0.0.1' },
        { 'HTTP_HOST' => '127.0.0.1:3000' },
        { 'HTTP_HOST' => 'example.com' },
        { 'HTTP_HOST' => '192.168.0.1', 'HTTP_X_FORWARDED_HOST' => '127.0.0.1' },
        { 'HTTP_HOST' => '192.168.0.1:3000', 'HTTP_X_FORWARDED_HOST' => '127.0.0.1:3000' },
        { 'HTTP_HOST' => '192.168.0.1', 'HTTP_X_FORWARDED_HOST' => 'example.com' },
        { 'HTTP_HOST' => '192.168.0.1', 'HTTP_X_FORWARDED_HOST' => 'example.com, 127.0.0.1' },
        { 'HTTP_HOST' => '192.168.0.1:3000', 'HTTP_X_FORWARDED_HOST' => 'example.com, 127.0.0.1:3000' },
        { 'HTTP_HOST' => '192.168.0.1', 'HTTP_FORWARDED' => 'host=127.0.0.1' },
        { 'HTTP_HOST' => '192.168.0.1', 'HTTP_FORWARDED' => 'host=example.com' },
        { 'HTTP_HOST' => '192.168.0.1', 'HTTP_FORWARDED' => 'host=example.com; host=127.0.0.1' },
        { 'HTTP_HOST' => '192.168.0.1:3000', 'HTTP_FORWARDED' => 'host=example.com; host=127.0.0.1:3000' }
      ]
    end

    bad_requests.call.each do |headers|
      it "stops the request with headers '#{headers}'" do
        permitted_hosts = [IPAddr.new('192.168.0.1')]
        mock_app do
          use Rack::Protection::HostAuthorization, permitted_hosts: permitted_hosts
          run DummyApp
        end

        get('/', {}, headers)

        assert_response(outcome: :stopped, headers: headers, last_response: last_response)
      end
    end
  end

  describe "when the permitted hosts are ['allowed.org']" do
    good_requests = lambda do |allowed_host|
      [
        { 'HTTP_HOST' => allowed_host },
        { 'HTTP_HOST' => "#{allowed_host}:3000" },
        { 'HTTP_HOST' => allowed_host, 'HTTP_X_FORWARDED_HOST' => allowed_host },
        { 'HTTP_HOST' => allowed_host, 'HTTP_X_FORWARDED_HOST' => "example.com, #{allowed_host}" },
        { 'HTTP_HOST' => allowed_host, 'HTTP_FORWARDED' => "host=#{allowed_host}" },
        { 'HTTP_HOST' => allowed_host, 'HTTP_FORWARDED' => "host=example.com; host=#{allowed_host}" }
      ]
    end

    good_requests.call('allowed.org').each do |headers|
      it "allows the request with headers '#{headers}'" do
        permitted_hosts = ['allowed.org']
        mock_app do
          use Rack::Protection::HostAuthorization, permitted_hosts: permitted_hosts
          run DummyApp
        end

        get('/', {}, headers)

        assert_response(outcome: :allowed, headers: headers, last_response: last_response)
      end
    end

    bad_requests = lambda do |allowed_host, bad_host|
      [
        { 'HTTP_HOST' => bad_host },
        { 'HTTP_HOST' => "#{bad_host}##{allowed_host}" },
        { 'HTTP_HOST' => allowed_host, 'HTTP_X_FORWARDED_HOST' => bad_host },
        { 'HTTP_HOST' => allowed_host, 'HTTP_X_FORWARDED_HOST' => "#{allowed_host}, #{bad_host}" },
        { 'HTTP_HOST' => allowed_host, 'HTTP_FORWARDED' => "host=#{bad_host}" },
        { 'HTTP_HOST' => allowed_host, 'HTTP_FORWARDED' => "host=#{allowed_host}; host=#{bad_host}" },
        { 'HTTP_HOST' => allowed_host, 'HTTP_X_FORWARDED_HOST' => bad_host },
        { 'HTTP_HOST' => allowed_host, 'HTTP_FORWARDED' => "host=#{bad_host}" },
        { 'HTTP_HOST' => allowed_host, 'HTTP_FORWARDED' => %(host=".#{allowed_host}") },
        { 'HTTP_HOST' => allowed_host, 'HTTP_FORWARDED' => %(host="foo.#{allowed_host}") },
        { 'HTTP_HOST' => bad_host, 'HTTP_X_FORWARDED_HOST' => allowed_host },
        { 'HTTP_HOST' => bad_host, 'HTTP_FORWARDED' => "host=#{allowed_host}" }
      ]
    end

    bad_requests.call('allowed.org', 'bad.org').each do |headers|
      it "stops the request with headers '#{headers}'" do
        permitted_hosts = ['allowed.org']
        mock_app do
          use Rack::Protection::HostAuthorization, permitted_hosts: permitted_hosts
          run DummyApp
        end

        get('/', {}, headers)

        assert_response(outcome: :stopped, headers: headers, last_response: last_response)
      end
    end
  end

  it 'has debug logging' do
    io = StringIO.new
    logger = Logger.new(io)
    logger.level = Logger::DEBUG
    allowed_host = 'allowed.org'
    mock_app do
      use Rack::Protection::HostAuthorization, logger: logger,
                                               permitted_hosts: [allowed_host]
      run DummyApp
    end

    get('/')

    expect(io.string).to match(/Rack::Protection::HostAuthorization.+#{allowed_host}/)
  end

  it 'accepts requests for unrecognized hosts when allow_if is true' do
    allowed_host = 'allowed.org'
    bad_host = 'bad.org'
    mock_app do
      use Rack::Protection::HostAuthorization, allow_if: ->(_env) { true },
                                               permitted_hosts: [allowed_host]
      run DummyApp
    end

    get('/', {}, 'HTTP_HOST' => bad_host)

    expect(last_response).to be_ok
  end

  it 'allows the response for blocked requests to be customized' do
    allowed_host = 'allowed.org'
    bad_host = 'bad.org'
    message = 'Unrecognized host'
    mock_app do
      use Rack::Protection::HostAuthorization, message: message,
                                               status: 406,
                                               permitted_hosts: [allowed_host]
      run DummyApp
    end

    get('/', {}, 'HTTP_HOST' => bad_host)

    expect(last_response.status).to eq(406)
    expect(last_response.body).to eq(message)
  end

  describe 'when HTTP_HOST is not present in the environment' do
    it 'stops the request' do
      app = mock_app do
        use Rack::Protection::HostAuthorization, permitted_hosts: ['.tld']
        run DummyApp
      end

      headers = { 'HTTP_X_FORWARDED_HOST' => 'foo.tld' }
      request = Rack::MockRequest.new(app) # this is from rack, not rack-test
      response = request.get('/', headers)

      expect(response.status).to eq(403)
      expect(response.body).to eq('Host not permitted')
    end
  end

  describe 'when the header value is upcased but the permitted host not' do
    test_cases = lambda do |host_in_request|
      [
        { 'HTTP_HOST' => host_in_request },
        { 'HTTP_HOST' => host_in_request, 'HTTP_X_FORWARDED_HOST' => host_in_request },
        { 'HTTP_HOST' => host_in_request, 'HTTP_FORWARDED' => "host=#{host_in_request}" }
      ]
    end

    test_cases.call('allowed.org'.upcase).each do |headers|
      it "allows the request with headers '#{headers}'" do
        mock_app do
          use Rack::Protection::HostAuthorization, permitted_hosts: ['allowed.org']
          run DummyApp
        end

        get('/', {}, headers)

        expect(last_response).to be_ok
      end
    end
  end

  describe 'when the permitted host is upcased but the header value is not' do
    test_cases = lambda do |host_in_request|
      [
        { 'HTTP_HOST' => host_in_request },
        { 'HTTP_HOST' => host_in_request, 'HTTP_X_FORWARDED_HOST' => host_in_request },
        { 'HTTP_HOST' => host_in_request, 'HTTP_FORWARDED' => "host=#{host_in_request}" }
      ]
    end

    test_cases.call('allowed.org').each do |headers|
      it "allows the request with headers '#{headers}'" do
        mock_app do
          use Rack::Protection::HostAuthorization, permitted_hosts: ['allowed.org'.upcase]
          run DummyApp
        end

        get('/', {}, headers)

        expect(last_response).to be_ok
      end
    end
  end
end
