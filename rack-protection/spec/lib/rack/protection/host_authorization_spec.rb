# frozen_string_literal: true

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
      expect(last_response.body).to eq("Host not permitted"), fail_message
    end
  end

  describe "when permitted hosts include IPAddr instance for 0.0.0.0/0" do
    good_requests = lambda do
      [
        { "HTTP_HOST" => "127.0.0.1" },
        { "HTTP_HOST" => "127.0.0.1:3000" },
        { "HTTP_X_FORWARDED_HOST" => "127.0.0.1" },
        { "HTTP_X_FORWARDED_HOST" => "127.0.0.1:3000" },
        { "HTTP_X_FORWARDED_HOST" => "example.com, 127.0.0.1" },
        { "HTTP_X_FORWARDED_HOST" => "example.com, 127.0.0.1:3000" },
        { "HTTP_FORWARDED" => "host=127.0.0.1" },
        { "HTTP_FORWARDED" => "host=example.com; host=127.0.0.1" },
        { "HTTP_FORWARDED" => "host=example.com; host=127.0.0.1:3000" },
      ]
    end

    good_requests.call.each do |headers|
      it "allows the request with headers '#{headers}'" do
        permitted = IPAddr.new("0.0.0.0/0")
        mock_app do
          use Rack::Protection::HostAuthorization, permitted_hosts: [permitted]
          run DummyApp
        end

        get("/", {}, headers)

        assert_response(outcome: :allowed, headers: headers, last_response: last_response)
      end
    end
  end

  describe "when permitted hosts include IPAddr instance for 192.168.0.1/32" do
    bad_requests = lambda do
      [
        { "HTTP_HOST" => "127.0.0.1" },
        { "HTTP_HOST" => "127.0.0.1:3000" },
        { "HTTP_HOST" => "example.com" },
        { "HTTP_X_FORWARDED_HOST" => "127.0.0.1" },
        { "HTTP_X_FORWARDED_HOST" => "127.0.0.1:3000" },
        { "HTTP_X_FORWARDED_HOST" => "example.com" },
        { "HTTP_X_FORWARDED_HOST" => "example.com, 127.0.0.1" },
        { "HTTP_X_FORWARDED_HOST" => "example.com, 127.0.0.1:3000" },
        { "HTTP_FORWARDED" => "host=127.0.0.1" },
        { "HTTP_FORWARDED" => "host=example.com" },
        { "HTTP_FORWARDED" => "host=example.com; host=127.0.0.1" },
        { "HTTP_FORWARDED" => "host=example.com; host=127.0.0.1:3000" },
      ]
    end

    bad_requests.call.each do |headers|
      it "stops the request with headers '#{headers}'" do
        permitted = IPAddr.new("192.168.0.1")
        mock_app do
          use Rack::Protection::HostAuthorization, permitted_hosts: [permitted]
          run DummyApp
        end

        get("/", {}, headers)

        assert_response(outcome: :stopped, headers: headers, last_response: last_response)
      end
    end
  end

  good_requests = lambda do |allowed_host|
    [
      { "HTTP_HOST" => allowed_host },
      { "HTTP_HOST" => "#{allowed_host}:3000" },
      { "HTTP_X_FORWARDED_HOST" => allowed_host },
      { "HTTP_X_FORWARDED_HOST" => "example.com, #{allowed_host}" },
      { "HTTP_FORWARDED" => "host=#{allowed_host}" },
      { "HTTP_FORWARDED" => "host=example.com; host=#{allowed_host}" },
    ]
  end

  good_requests.call("allowed.org").each do |headers|
    it "allows the request with headers '#{headers}'" do
      mock_app do
        use Rack::Protection::HostAuthorization, permitted_hosts: ["allowed.org"]
        run DummyApp
      end

      get("/", {}, headers)

      assert_response(outcome: :allowed, headers: headers, last_response: last_response)
    end
  end

  bad_requests = lambda do |allowed_host, bad_host|
    [
      { "HTTP_HOST" => bad_host },
      { "HTTP_X_FORWARDED_HOST" => bad_host },
      { "HTTP_X_FORWARDED_HOST" => "#{allowed_host}, #{bad_host}" },
      { "HTTP_FORWARDED" => "host=#{bad_host}" },
      { "HTTP_FORWARDED" => "host=#{allowed_host}; host=#{bad_host}" },
      { "HTTP_HOST" => allowed_host, "HTTP_X_FORWARDED_HOST" => bad_host },
      { "HTTP_HOST" => allowed_host, "HTTP_FORWARDED" => "host=#{bad_host}" },
    ]
  end

  bad_requests.call("allowed.org", "bad.org").each do |headers|
    it "stops the request with headers '#{headers}'" do
      mock_app do
        use Rack::Protection::HostAuthorization, permitted_hosts: ["allowed.org"]
        run DummyApp
      end

      get("/", {}, headers)

      assert_response(outcome: :stopped, headers: headers, last_response: last_response)
    end
  end

  it "accepts requests for unrecognized hosts when allow_if is true" do
    allowed_host = "allowed.org"
    bad_host = "bad.org"
    mock_app do
      use Rack::Protection::HostAuthorization, allow_if: ->(_env) { true },
                                               permitted_hosts: [allowed_host]
      run DummyApp
    end

    get("/", {}, "HTTP_HOST" => bad_host)

    expect(last_response).to be_ok
  end

  it "allows the response for blocked requests to be customized" do
    allowed_host = "allowed.org"
    bad_host = "bad.org"
    message = "Unrecognized host"
    mock_app do
      use Rack::Protection::HostAuthorization, message: message,
                                               status: 406,
                                               permitted_hosts: [allowed_host]
      run DummyApp
    end

    get("/", {}, "HTTP_HOST" => bad_host)

    expect(last_response.status).to eq(406)
    expect(last_response.body).to eq(message)
  end

  describe "when the header value is upcased but the permitted host not" do
    test_cases = lambda do |host_in_request|
      [
        { "HTTP_HOST" => host_in_request },
        { "HTTP_X_FORWARDED_HOST" => host_in_request },
        { "HTTP_FORWARDED" => "host=#{host_in_request}" },
      ]
    end

    test_cases.call("allowed.org".upcase).each do |headers|
      it "allows the request with headers '#{headers}'" do
        mock_app do
          use Rack::Protection::HostAuthorization, permitted_hosts: ["allowed.org"]
          run DummyApp
        end

        get("/", {}, headers)

        expect(last_response).to be_ok
      end
    end
  end

  describe "when the permitted host is upcased but the header value is not" do
    test_cases = lambda do |host_in_request|
      [
        { "HTTP_HOST" => host_in_request },
        { "HTTP_X_FORWARDED_HOST" => host_in_request },
        { "HTTP_FORWARDED" => "host=#{host_in_request}" },
      ]
    end

    test_cases.call("allowed.org").each do |headers|
      it "allows the request with headers '#{headers}'" do
        mock_app do
          use Rack::Protection::HostAuthorization, permitted_hosts: ["allowed.org".upcase]
          run DummyApp
        end

        get("/", {}, headers)

        expect(last_response).to be_ok
      end
    end
  end
end
