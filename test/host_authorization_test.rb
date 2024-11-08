# frozen_string_literal: true

require_relative "test_helper"

class HostAuthorization < Minitest::Test
  it "allows requests based on the permitted hosts specified" do
    allowed_host = "allowed.org"
    mock_app do
      set :host_authorization, { permitted_hosts: [allowed_host] }

      get("/") { "OK" }
    end

    headers = { "HTTP_HOST" => allowed_host }
    request = Rack::MockRequest.new(@app)
    response = request.get("/", headers)

    assert_equal 200, response.status
    assert_equal "OK", response.body
  end

  it "stops requests based on the permitted hosts specified" do
    allowed_host = "allowed.org"
    mock_app do
      set :host_authorization, { permitted_hosts: [allowed_host] }

      get("/") { "OK" }
    end

    headers = { "HTTP_HOST" => "bad-host.org" }
    request = Rack::MockRequest.new(@app)
    response = request.get("/", headers)

    assert_equal 403, response.status
    assert_equal "Host not permitted", response.body
  end

  it "allows any requests when no permitted hosts are specified" do
    mock_app do
      set :host_authorization, { permitted_hosts: [] }

      get("/") { "OK" }
    end

    headers = { "HTTP_HOST" => "some-host.org" }
    request = Rack::MockRequest.new(@app)
    response = request.get("/", headers)

    assert_equal 200, response.status
    assert_equal "OK", response.body
  end

  it "stops the request using the configured response" do
    allowed_host = "allowed.org"
    status = 418
    message = "No coffee for you"
    mock_app do
      set :host_authorization, {
        permitted_hosts: [allowed_host],
        status: status,
        message: message,
      }

      get("/") { "OK" }
    end

    headers = { "HTTP_HOST" => "bad-host.org" }
    request = Rack::MockRequest.new(@app)
    response = request.get("/", headers)

    assert_equal status, response.status
    assert_equal message, response.body
  end

  it "allows custom logic with 'allow_if'" do
    allowed_host = "allowed.org"
    mock_app do
      set :host_authorization, {
        permitted_hosts: [allowed_host],
        allow_if: ->(_env) { true },
      }

      get("/") { "OK" }
    end

    headers = { "HTTP_HOST" => "some-host.org" }
    request = Rack::MockRequest.new(@app)
    response = request.get("/", headers)

    assert_equal 200, response.status
    assert_equal "OK", response.body
  end
end
